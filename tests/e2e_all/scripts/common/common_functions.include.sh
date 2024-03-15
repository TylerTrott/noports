RED='\033[0;31m'
NC='\033[0m'

getReportFile() {
  echo "/tmp/e2e_all/${commitId}.test.report"
}

getNoFlagsDeviceNameForCommitIDTypeAndVersion() {
  if (( $# != 2 )) ; then
    logError "getNoFlagsDeviceNameForCommitIDTypeAndVersion expects two parameters; $# were supplied"
    exit 1
  fi
  commitId="$1"
  typeAndVersion="$2"
  IFS=: read -r type version <<< "$typeAndVersion"
  versionForDeviceName=$(echo "$version" | tr -d ".")
  if test "$versionForDeviceName" = "current"; then
    versionForDeviceName="c";
  fi
  echo "${commitId}${type}${versionForDeviceName}"
}

OS=""
iso8601Date() {
  if test "$OS" == ""; then
    OS=$(uname -s)
  fi
  if test "$OS" == "Darwin"; then
    # no milliseconds in Darwin
    date +"%Y-%m-%d %H:%M:%S"
  else
    date +"%Y-%m-%d %H:%M:%S.%3N"
  fi
}

logError() {
  echo -e "$(iso8601Date) |     ${RED}ERROR:${NC} $1"
}

logErrorAndExit() {
  logError "$1"
  exit 1
}

logInfo() {
  echo "$(iso8601Date) | $1"
}

getDartCompilationOutputDir() {
  echo "$testRuntimeDir/binaries/branch"
}

getDartReleaseDirForVersion() {
  version="$1"
  echo "$testRootDir/releases/dart.$version"
}

getDartReleaseBinDirForVersion() {
  version="$1"
  echo "$testRootDir/releases/dart.$version/sshnp"
}

versionIsLessThan() {
  actualTypeAndVersion="$1"
  typeAndVersionList="$2"
  IFS=: read -r aType aVersion <<< "$actualTypeAndVersion"

  IFS=. read -r aMaj aMin aPat <<< "$aVersion"

  for rtv in $typeAndVersionList
  do
    IFS=: read -r rType rVersion <<< "$rtv"
    if [[ "$aType" == "$rType" ]]; then
      if [[ "$aVersion" == "current" ]]; then
        # actual version 'current' is never less than anything
        echo "false"
        return
      fi

      IFS=. read -r rMaj rMin rPat <<< "$rVersion"
      if (( aMaj < rMaj )); then
        echo "true"
        return
      fi
      if (( aMaj > rMaj )); then
        echo "false"
        return
      fi

      # major versions are the same - compare minor versions
      if (( aMin < rMin )); then
        echo "true"
        return
      fi
      if (( aMin > rMin )); then
        echo "false"
        return
      fi

      # minor versions are the same - compare patch versions
      if (( aPat < rPat )); then
        echo "true"
        return
      else
        echo "false"
        return
      fi
    fi
  done

  # If we didn't return during the loop above, then we return false
  echo "false"
}

versionIsAtLeast() {
  # Given actual of "type_1:5.0.2" and required of "type_1:4.0.5 type_2:4.0.1
  # We find the 'type_1:' entry in the required list
  #   return FALSE if there is no 'type_1:' entry
  #   return FALSE if the actual version is >= the required version
  #   return TRUE if not
  actualTypeAndVersion="$1"
  typeAndVersionList="$2"
  IFS=: read -r aType aVersion <<< "$actualTypeAndVersion"

  IFS=. read -r aMaj aMin aPat <<< "$aVersion"

  # for required in required list
  for rtv in $typeAndVersionList
  do
    IFS=: read -r rType rVersion <<< "$rtv"
    if [[ "$aType" == "$rType" ]]; then
      if [[ "$aVersion" == "current" ]]; then
        # actual version 'current' is always at least what is required
        echo "true"
        return
      fi

      IFS=. read -r rMaj rMin rPat <<< "$rVersion"
      if (( aMaj < rMaj )); then # not at required major version
        echo "false"
        return
      fi
      if (( aMaj > rMaj )); then # beyond the required major version
        echo "true"
        return
      fi

      # major versions are the same - compare minor versions
      if (( aMin < rMin )); then # not at required minor version
        echo "false"
        return
      fi
      if (( aMin > rMin )); then
        echo "true"
        return
      fi

      # minor versions are the same - compare patch versions
      if (( aPat < rPat )); then # not at required patch version
        echo "false"
        return
      else
        echo "true"
        return
      fi
    fi
  done

  # If we didn't return during the loop above, then we return false
  echo "false"
}

# if test isLessThan "$daemonVersion" "d:5.0.0"; then

getPathToBinariesForTypeAndVersion() {
  if (( $# != 1 )) ; then
    logError "getPathToBinariesForTypeAndVersion expects one parameter, but was supplied $#"
    exit 1
  fi
  typeAndVersion="$1"
  IFS=: read -r type version <<< "$typeAndVersion"

  case "$version" in
    current)
      case "$type" in
        d) # dart
          getDartCompilationOutputDir
          ;;
        *)
          logErrorAndExit "Don't know how to getPathToBinariesForTypeAndVersion for $typeAndVersion"
          ;;
      esac
      ;;
    *)
      case "$type" in
        d) # dart
          getDartReleaseBinDirForVersion "$version"
          ;;
        *)
          logErrorAndExit "Don't know how to getPathToBinariesForTypeAndVersion for $typeAndVersion"
          ;;
      esac
      ;;
  esac
}

setupDartVersion() {
  version="$1"

  if test "$version" = "current"; then
    buildCurrentDartBinaries || exit $?
  else
    downloadDartBinaries "$version" || exit $?
  fi
}

buildCurrentDartBinaries() {
  compileVerbosity=error

  logInfo "    Compiling Dart binaries for current git commitId $commitId"

  binaryOutputDir=$(getDartCompilationOutputDir)
  mkdir -p "$binaryOutputDir"

  if [ "$recompile" = "true" ]; then
    cd "$binaryOutputDir" || exit 1
    rm -f activate_cli srv sshnpd srvd sshnp npt
  fi

  binarySourceDir="$repoRootDir/packages/dart/sshnoports"
  if ! [ -d "$binarySourceDir" ]; then
    logErrorAndExit "Directory $binarySourceDir does not exist. Has package structure changed? "
    exit 1
  fi
  cd "$binarySourceDir" || exit 1

  logInfo "    dart pub get"
  dart pub get || exit 1

  if [ -f "$binaryOutputDir/activate_cli" ]; then
    logInfo "        $binaryOutputDir/activate_cli has already been compiled"
  else
    logInfo "        Compiling activate_cli"
    dart compile exe --verbosity "$compileVerbosity" bin/activate_cli.dart -o "$binaryOutputDir/activate_cli"
  fi

  if [ -f "$binaryOutputDir/srv" ]; then
    logInfo "        $binaryOutputDir/srv has already been compiled"
  else
    logInfo "        Compiling srv"
    dart compile exe --verbosity "$compileVerbosity" bin/srv.dart -o "$binaryOutputDir/srv"
  fi

  if [ -f "$binaryOutputDir/sshnpd" ]; then
    logInfo "        $binaryOutputDir/sshnpd has already been compiled"
  else
    logInfo "        Compiling sshnpd"
    dart compile exe --verbosity "$compileVerbosity" bin/sshnpd.dart -o "$binaryOutputDir/sshnpd"
  fi

  if [ -f "$binaryOutputDir/srvd" ]; then
    logInfo "        $binaryOutputDir/srvd has already been compiled"
  else
    logInfo "        Compiling srvd"
    dart compile exe --verbosity "$compileVerbosity" bin/srvd.dart -o "$binaryOutputDir/srvd"
  fi

  if [ -f "$binaryOutputDir/sshnp" ]; then
    logInfo "        $binaryOutputDir/sshnp has already been compiled"
  else
    logInfo "        Compiling sshnp"
    dart compile exe --verbosity "$compileVerbosity" bin/sshnp.dart -o "$binaryOutputDir/sshnp"
  fi

  if [ -f "$binaryOutputDir/npt" ]; then
    logInfo "        $binaryOutputDir/npt has already been compiled"
  else
    logInfo "        Compiling npt"
    dart compile exe --verbosity "$compileVerbosity" bin/npt.dart -o "$binaryOutputDir/npt"
  fi
}

downloadDartBinaries() {
  version="$1"

  versionBinDir=$(getDartReleaseDirForVersion "$version")
  mkdir -p "$versionBinDir"
  # https://github.com/atsign-foundation/noports/releases/download/v4.0.5/sshnp-macos-arm64.zip
  # https://github.com/atsign-foundation/noports/releases/download/v4.0.5/sshnp-linux-x64.tgz

  #   Check if $versionBinDir contains the zip
  #   If it contains the zip, check that the binaries have been unzipped
  #   If binaries have not been unzipped, unzip them
  downloadZipName="sshnp-$OS-$ARCH.$EXT"
  logInfo "    Getting binaries for Dart release $version"

  if [ -f "$versionBinDir/$downloadZipName" ]; then
    logInfo "        $versionBinDir/$downloadZipName has already been downloaded"
  else
    baseUrl="https://github.com/atsign-foundation/noports/releases/download"
    downloadUrl="$baseUrl/v$version/$downloadZipName"
    logInfo "        Downloading $downloadUrl to $versionBinDir/$downloadZipName"
    curl -f -s -L -X GET "$downloadUrl" -o "$versionBinDir/$downloadZipName"
    retCode=$?
    if test "$retCode" != 0; then
      logErrorAndExit "Failed to download $downloadUrl with curl exit status $retCode"
    fi
  fi

  # Unzip if not already unzipped
  if ! [ -d "$versionBinDir/sshnp" ]; then
    case "$EXT" in
      zip)
        unzip -qo "$versionBinDir/$downloadZipName" -d "$versionBinDir";
        ;;
      tgz|tar.gz)
        tar -zxf "$versionBinDir/$downloadZipName" -C "$versionBinDir";
        ;;
    esac
  fi

  #   Symbolic link the releases/$version/binaries into this commit's runtime/binaries directory
  rm -f "${testRuntimeDir}/binaries/dart.${version}"
  ln -s "$versionBinDir/sshnp" "${testRuntimeDir}/binaries/dart.${version}"
}

#! /bin/zsh

# Set java_home to the provided version.
# Args: $1 = version number (21, 17, etc)
set_java_home() {
  export JAVA_HOME=$(/usr/libexec/java_home -v $1)
  echo "JAVA_HOME=$JAVA_HOME"
}

j21() {
  set_java_home 21
}

j19() {
  set_java_home 19
}

j17() {
  set_java_home 17
}

j11() {
  set_java_home 11
}

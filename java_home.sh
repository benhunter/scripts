#! /bin/zsh

j21() {
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)
  echo "JAVA_HOME=$JAVA_HOME"
}

j19() {
  export JAVA_HOME=$(/usr/libexec/java_home -v 19)
  echo "JAVA_HOME=$JAVA_HOME"
}

j17() {
  export JAVA_HOME=$(/usr/libexec/java_home -v 17)
  echo "JAVA_HOME=$JAVA_HOME"
}

j11() {
  export JAVA_HOME=$(/usr/libexec/java_home -v 11)
  echo "JAVA_HOME=$JAVA_HOME"
}

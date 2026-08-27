@ECHO OFF
SET DIR=%~dp0
IF EXIST "%JAVA_HOME%\bin\java.exe" (SET JAVA_EXE=%JAVA_HOME%\bin\java.exe) ELSE (SET JAVA_EXE=java.exe)
"%JAVA_EXE%" -classpath "%DIR%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*

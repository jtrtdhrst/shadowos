Option Explicit

Dim fileSystem, shell, powerShellPath, scriptPath, repositoryPath, command, exitCode

If WScript.Arguments.Count <> 2 Then
    WScript.Quit 2
End If

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
powerShellPath = fileSystem.BuildPath(fileSystem.GetSpecialFolder(1), "WindowsPowerShell\v1.0\powershell.exe")
scriptPath = WScript.Arguments(0)
repositoryPath = WScript.Arguments(1)

command = Quote(powerShellPath) & _
    " -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & _
    Quote(scriptPath) & " -RepositoryPath " & Quote(repositoryPath)
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode

Function Quote(value)
    Quote = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function

#ifndef Name
#define Name "proxy-choco"
#endif

#ifndef Version
#define Version "0.0.0"
#endif

#define Publisher "KarbyshevDm"

[Setup]
AppId={{8b3a1c40-95e2-4da5-b3ab-df99e9ef39a0}}
AppName={#Name}
AppVersion={#Version}
AppPublisher={#Publisher}
DefaultDirName={commonpf64}\{#Name}
DefaultGroupName={#Name}
SourceDir={#SourceFilesDirectory}
OutputDir={#OutputDirectory}
OutputBaseFilename={#OutputFileName}

AlwaysRestart = no
UninstallRestartComputer = no
DirExistsWarning = no

SolidCompression=yes
Compression=lzma

PrivilegesRequired = admin
ArchitecturesAllowed = x64

RestartApplications = no
CloseApplications = no

DisableWelcomePage = yes
DisableDirPage = yes
DisableProgramGroupPage = yes
DisableFinishedPage = no


[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"; 

[Files]
Source: "appsettings.json"; DestDir: "{app}"; Flags: ignoreversion;      
Source: "ProxyChocoGrpcService.exe"; DestDir: "{app}"; Flags: ignoreversion; AfterInstall: InstallService(); 
Source: "{#Name}.exe"; DestDir: "{app}"; Flags: ignoreversion;  AfterInstall:
// AddToPath();
//[Run]
//Filename: "setx"; Parameters: "/M PATH ""%PATH%;{app};=%""";
//  AfterInstall: ShellExec('setx /M PATH "%PATH%;D:\proxy-choco\');
//setx /M PATH "%PATH%;D:\proxy-choco\
[UninstallRun]
Filename: "sc"; Parameters: "stop ProxyChocoService";
Filename: "sc"; Parameters: "delete ProxyChocoService";
//Filename: "setx"; Parameters: "/M PATH ""%PATH:{app};=%""";
//[UninstallDelete]
//Type: filesandordirs; Name: "{app}"; BeforeInstall: UninstallService();




[code]
function CheckServiceExists(): Boolean;
var
  ResultCode: Integer;
  ExecResult: Boolean;
begin
  
  ExecResult := Exec('sc', 'query ProxyChocoService','',SW_SHOW,ewWaitUntilTerminated,ResultCode);
  if(ExecResult) then
  begin
    if (ResultCode = 0) then
    begin
      Result:= True;
    end
    else begin
      Result:= False;
    end;
  end;
end;

procedure UninstallService();
 var
  ErrorCode: Integer;
  ResultCode: Integer;
  ExecCreateServiceResult: Boolean;
  ExecStartServiceResult: Boolean;
begin
  if CheckServiceExists() then
  begin
    Exec('sc', 'stop ProxyChocoService', '',SW_SHOW,ewWaitUntilTerminated,ResultCode);
    Exec('sc', 'delete ProxyChocoService', '',SW_SHOW,ewWaitUntilTerminated,ResultCode);
  end;
end;


procedure InstallService();
var
  ErrorCode: Integer;
  ResultCode: Integer;
  ExecCreateServiceResult: Boolean;
  ExecStartServiceResult: Boolean;



begin
  UninstallService();
  if not CheckServiceExists() then
  begin
   ExecCreateServiceResult:= Exec('sc','create "ProxyChocoService" binPath= "'+ ExpandConstant('{app}')+'\ProxyChocoGrpcService.exe" start= auto','',0,ewWaitUntilTerminated,ResultCode);
   if (ExecCreateServiceResult)  then
     ExecStartServiceResult:= Exec('sc', 'start ProxyChocoService', '',0,ewWaitUntilTerminated,ResultCode);
     if (not ExecStartServiceResult or (ResultCode <> 0)) then
      MsgBox('Ошибка при запуске службы! ('+IntToStr(ResultCode) + ')', mbError, MB_OK);
 end;
end;

procedure SetupPath();
 var
  ErrorCode: Integer;
  ResultCode: Integer;
  ExecCheckPathResult: Boolean;
  ExecStartServiceResult: Boolean;
 begin
   ExecCheckPathResult:= Exec('echo', ' %PATH% | find /C /I ""C:\Windows\system32'+ExpandConstant('{app}')+'"', '',SW_SHOW,ewWaitUntilTerminated,ResultCode); 
 end;  



function GetSystemPath(): string;
var
  pathIsGot: Boolean;
  path: string;
begin 
  pathIsGot := RegQueryStringValue(HKEY_LOCAL_MACHINE,'SYSTEM\CurrentControlSet\Control\Session Manager\Environment','Path',path);
  
  if length(path) > 0 then
    Result := path;
end;

function SetEnvironmentVariable(const VarName: string; const VarValue: string): boolean;
 var
  ErrorCode: Integer;
  ResultCode: Integer;
  ExecSetEnvResult: Boolean;
begin
   ExecSetEnvResult:= Exec('setx', '/m '+VarName+' "'+VarValue+'"', '',SW_SHOW,ewWaitUntilTerminated,ResultCode);
end;                                                                                                                                         

procedure AddToPath(const Path: string);
var 
  OldPath: string;
  NewPath: string;
begin
  OldPath := GetSystemPath();
  if Pos(Path + ';', OldPath) = 0 then begin
    if OldPath <> '' then
      NewPath := OldPath  +';'+ Path
    else
      NewPath := Path;
    SetEnvironmentVariable('PATH', NewPath);
  end     
end;

procedure RemoveFromPath(const Path: string);
var
  OldPath: string;
  NewPath: string;
  i: integer;
begin
  OldPath := GetSystemPath();
  i := Pos(Path + ';', OldPath);
  if Pos(Path + ';', OldPath) > 0 then begin
    Delete(OldPath, i, length(Path));
    SetEnvironmentVariable('PATH', OldPath);
  end 
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    AddToPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RemoveFromPath(ExpandConstant('{app}'));
    UninstallService();
end;

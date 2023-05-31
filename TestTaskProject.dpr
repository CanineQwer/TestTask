program TestTaskProject;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Classes, SyncObjs, SysUtils;

const
  CValueEnd = 1000000;
  CNameGeneralFile = 'Result.txt';

var
  GCurrentValue: Integer;
  GWhoLastGetValue: Integer;

type
  TMyThead = class(TThread)
  private
    FNumForFile: Char;
    FNumForWho: Integer;
  protected
    procedure Execute; override;
  public
    property NumForFile: Char read FNumForFile write FNumForFile;
    property NumForWho: Integer read FNumForWho write FNumForWho;
  end;

  TMyMutex = class
  private
    FMutex: TMutex;
  public
    constructor Create(skey: String);
    destructor Destroy; override;
    procedure Lock;
    procedure Unlock;
  end;

  constructor TMyMutex.Create(skey: String);
  begin
    FMutex := SyncObjs.TMutex.Create(nil, False, skey);
  end;

  destructor TMyMutex.Destroy;
  begin
    FMutex.Free;
    inherited;
  end;

  procedure TMyMutex.Lock;
  begin
    FMutex.Acquire;
  end;

  procedure TMyMutex.Unlock;
  begin
    FMutex.Release;
  end;

  procedure TMyThead.Execute;
  var
    LCurrentValueMutex: TMyMutex;
    LWhoLastGetValue: TMyMutex;
    LWriteGeneralFileMutex: TMyMutex;
    LCurrentValue: Integer;
    I: integer;
    LIsSimple: Boolean;
    LGeneralFile, LOneThreadFile : TextFile;
    LNameOneThreadFile: String;
  begin
    LCurrentValueMutex := TMyMutex.Create('CurrentValueMutex');
    LWhoLastGetValue := TMyMutex.Create('WhoLastGetValue');
    LWriteGeneralFileMutex := TMyMutex.Create('WriteGeneralFileMutex');

    LNameOneThreadFile := 'Thread' + NumForFile + '.txt';

    AssignFile(LOneThreadFile, LNameOneThreadFile);
    Rewrite(LOneThreadFile);

    try
      while True do
      begin
        LCurrentValueMutex.Lock;
        LCurrentValue := GCurrentValue;
        GCurrentValue := GCurrentValue + 1;
        LCurrentValueMutex.Unlock;

        if (GCurrentValue > CValueEnd) then
          break;

        LWhoLastGetValue.Lock;
        while (GWhoLastGetValue = FNumForWho) do
        begin
          LWhoLastGetValue.Unlock;
          Sleep(10);
          LWhoLastGetValue.Lock;
        end;

        GWhoLastGetValue := FNumForWho;
        LWhoLastGetValue.Unlock;

        LIsSimple := True;
        for I:= 2 to LCurrentValue - 1 do
          if (LCurrentValue mod I = 0) then
          begin
            LIsSimple := False;
            break;
          end;

        if (LIsSimple) then
        begin
          LWriteGeneralFileMutex.Lock;
          AssignFile(LGeneralFile, CNameGeneralFile);
          Append(LGeneralFile);
          Write(LGeneralFile, IntToStr(LCurrentValue) + ' ');
          CloseFile(LGeneralFile);
          LWriteGeneralFileMutex.Unlock;

          Append(LOneThreadFile);
          Write(LOneThreadFile, IntToStr(LCurrentValue) + ' ');
        end;
      end;
    finally
      LCurrentValueMutex.Free;
      LWhoLastGetValue.Free;
      LWriteGeneralFileMutex.Free;

      CloseFile(LOneThreadFile);
    end;
  end;

  function CreateThread(ANumForFile: Char; ANumForWho: Integer): TMyThead;
  begin
    Result := TMyThead.Create(True);
    Result.FreeOnTerminate := False;
    Result.NumForFile := ANumForFile;
    Result.NumForWho := ANumForWho;
    Result.Start;
  end;

var
  LMyThread1, LMyThread2 : TMyThead;
  LGeneralFile: TextFile;
begin
  GCurrentValue := 2;
  GWhoLastGetValue := 0;

  AssignFile(LGeneralFile, CNameGeneralFile);
  Rewrite(LGeneralFile);
  CloseFile(LGeneralFile);

  LMyThread1 := CreateThread('1', -1);
  LMyThread2 := CreateThread('2', +1);

  LMyThread1.WaitFor;
  LMyThread2.WaitFor;

  WriteLn('End');
  ReadLn;
end.

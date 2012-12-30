unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Unit2, semaphores, Synchropts, fgl;

const
  ltREADERS = 0;
  ltWRITERS = 1;
  ltFAIR = 2;

type

  TReader = class(TManagedThread)
   public
     TID: Cardinal;
     status: String;
     CyclesStall: Cardinal;
     constructor Create;
     procedure Execute; override;
  end;

  TWriter = class(TManagedThread)
    public
      TID: Cardinal;
      CyclesStall: Cardinal;
      status: String;
      constructor Create;
      procedure Execute; override;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    mCzytelnicy: TMemo;
    mPisarze: TMemo;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
  public
    procedure Step;
  end;

  TWritersList = specialize TFPGList<TWriter>;
  TReadersList = specialize TFPGList<TReader>;

var
  Form1: TForm1;
  logicType: Integer = -1;

  rWrt, rMutex: TSemaphore;
  rReadcount: Integer = 0;

  wReadcount: Integer = 0;
  wWritecount: Integer = 0;
  wMutex1, wMutex2, wMutex3, wW, wR: TSemaphore;

  WritersList: TWritersList;
  ReadersList: TReadersList;

  EverybodyWrites: Boolean = false;
  EverybodyReads: Boolean = false;

implementation

{$R *.lfm}

{ TForm1 }


// ----------------------------------------------

procedure TForm1.FormCreate(Sender: TObject);
begin
  rWrt := TSemaphore.Create(1,1);
  rMutex := TSemaphore.Create(1,1);

  wMutex1 := TSemaphore.Create(1,1);
  wMutex2 := TSemaphore.Create(1,1);
  wMutex3 := TSemaphore.Create(1,1);
  wW := TSemaphore.Create(1,1);
  wR := TSemaphore.Create(1,1);

end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  AddThread(TReader.Create);
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  AddThread(TWriter.Create);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
     if Timer1.Enabled then           // pause was pressed
     begin
          Timer1.Enabled := False;
          Button6.Enabled := True;
          Button5.Caption := 'PLAY';
     end else
     begin
       Timer1.Enabled := True;
       Button6.Enabled := False;
       Button5.Caption := 'PAUSE';
     end;
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
     Step;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  if logicType = -1 then Form2.ShowModal;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  Step;
end;

procedure TForm1.Step;
var
  i: Integer;
begin
     StartLockstep;

     mCzytelnicy.Clear;
     for i := 0 to ReadersList.Count-1 do
         mCzytelnicy.Lines.Append('#'+IntToStr(ReadersList[i].TID)+' '+ReadersList[i].Status);

     mPisarze.Clear;
     for i := 0 to WritersList.Count-1 do
         mPisarze.Lines.Append('#'+IntToStr(WritersList[i].TID)+' '+WritersList[i].Status);

     EndLockstep;
end;

// ----------------------------------------- Logic of readers and writers


procedure TWriter.Execute;
begin
  TID := GetThreadID();
  while True do
  begin
    // At this point, I'm sitting ducks.
    status := 'Nie robie nic';
    while CyclesStall > 0 do
    begin
      if EverybodyWrites then
      begin
           CyclesStall := 0;
           break;
      end;
      Dec(CyclesStall);
      SignalStep;
    end;

    status := 'Przygotowuje sie do pisania';
    SignalStep;


    // pick logic, pursue it
    CyclesStall := 5+random(8);
  end;
end;

procedure TReader.Execute;
begin
  TID := GetThreadID();
  while True do
  begin
    // At this point, I'm sitting ducks.
    status := 'Nie robie nic';
    while CyclesStall > 0 do
    begin
      if EverybodyReads then
      begin
           CyclesStall := 0;
           break;
      end;
      Dec(CyclesStall);
      SignalStep;
    end;

    status := 'Przygotowuje sie do czytania';
    SignalStep;


    // pick logic, pursue it
    CyclesStall := 3+random(9);
  end;
end;



constructor TWriter.Create;
begin
  status := 'Dopiero utworzony';
  CyclesStall := 3;
  WritersList.Add(self);
  inherited Create(False);
end;
constructor TReader.Create;
begin
  status := 'Dopiero utworzony';
  CyclesStall := 3;
  ReadersList.Add(self);
  inherited Create(False);
end;


initialization
begin
  ReadersList := TReadersList.Create;
  WritersList := TWritersList.Create;
end;
end.


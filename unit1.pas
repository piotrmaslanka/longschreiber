unit Unit1;
// Longschreiber - program ilustrujacy zagadnienie czytelników/pisarzy
// Copyright (c) Piotr Maślanka 2013, wszystkie prawa zastrzezone
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Unit2, semaphores, Synchropts, fgl;

ResourceString
  Author = 'Piotr Maślanka';
  AuthorEmail = 'piotr.maslanka@henrietta.com.pl';

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
    mutexesList: TMemo;
    mPisarze: TMemo;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }
  public
    procedure Step;
    procedure UpdateGraphics;
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

  fA, fR, fO: TSemaphore;
  nreaders: Cardinal = 0;

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

  fA := TSemaphore.Create(1,1);
  fR := TSemaphore.Create(1,1);
  fO := TSemaphore.Create(1,1);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  AddThread(TReader.Create);
  UpdateGraphics;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  AddThread(TWriter.Create);
  UpdateGraphics;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
   if EverybodyReads then
      Button3.Caption := 'Wymuś czytanie'
   else
      Button3.Caption := 'Nie wymuszaj czytania';
   EverybodyReads := not EverybodyReads;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
   if EverybodyWrites then
      Button4.Caption := 'Wymuś pisanie'
   else
      Button4.Caption := 'Nie wymuszaj pisania';
   EverybodyWrites := not EverybodyWrites;
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

procedure TForm1.UpdateGraphics;
          function SecondsElapsed(k: TDateTime): String;
          begin
            result := IntToStr(Round((Time-k)*86400));
          end;

var
  i: Integer;
begin
   mCzytelnicy.Clear;
   for i := 0 to ReadersList.Count-1 do
       mCzytelnicy.Lines.Append('#'+IntToStr(ReadersList[i].TID)+' ('+SecondsElapsed(ReadersList[i].LastReset)+') '+ReadersList[i].Status);

   mPisarze.Clear;
   for i := 0 to WritersList.Count-1 do
       mPisarze.Lines.Append('#'+IntToStr(WritersList[i].TID)+' ('+SecondsElapsed(WritersList[i].LastReset)+') '+WritersList[i].Status);

   mutexesList.Clear;
   if logicType = ltREADERS then // ------------------- READERS
   begin
        mutexesList.Lines.Append('W: '+IntToStr(rWrt.CurrentValue));
        mutexesList.Lines.Append('M: '+IntToStr(rWrt.CurrentValue));
        mutexesList.Lines.Append('Czytelników: '+IntToStr(rReadCount));
   end else if logicType = ltWRITERS then // ------------- WRITERS
   begin
        mutexesList.Lines.Append('M1: '+IntToStr(wMutex1.CurrentValue));
        mutexesList.Lines.Append('M2: '+IntToStr(wMutex2.CurrentValue));
        mutexesList.Lines.Append('M3: '+IntToStr(wMutex3.CurrentValue));
        mutexesList.Lines.Append('W: '+IntToStr(wW.CurrentValue));
        mutexesList.Lines.Append('R: '+IntToStr(wR.CurrentValue));
        mutexesList.Lines.Append('Czytelników: '+IntToStr(wReadCount));
        mutexesList.Lines.Append('Czekających pisarzy: '+IntToStr(wWriteCount));
   end else if logicType = ltFAIR then // -------------- FAIR
   begin
        mutexesList.Lines.Append('A: '+IntToStr(fA.CurrentValue));
        mutexesList.Lines.Append('R: '+IntToStr(fR.CurrentValue));
        mutexesList.Lines.Append('O: '+IntToStr(fO.CurrentValue));
        mutexesList.Lines.Append('Czytelników: '+IntToStr(nreaders));
   end;
end;

procedure TForm1.Step;
var
  i: Integer;
begin
     StartLockstep;
     UpdateGraphics;
     EndLockstep;
end;

// ----------------------------------------- Logic of readers and writers


procedure TWriter.Execute;
var
 i: Integer;
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

    if logicType = ltREADERS then
    begin
         status := 'Opuszczam W';
         SignalStep;
         rWrt.P();
         status := 'Piszę';
         for i := 0 to Random(3)+1 do ZeroStep;

         status := 'Podnosze W';
         SignalStep;
         rWrt.V();
    end;

    if logicType = ltWRITERS then
    begin
         status := 'Opuszczam M2';
         SignalStep;
         wMutex2.P();
         Inc(wWriteCount);
         if wWriteCount = 1 then
         begin
              status := 'Jestem pierwszym pisarzem';
              SignalStep;
              wR.P();
         end;
         status := 'Podnosze M2';
         SignalStep;
         wMutex2.V();

         status := 'Opuszczam W';
         SignalStep;
         wW.P();

         status := 'Piszę';
         for i := 0 to Random(3)+1 do ZeroStep;

         status := 'Podnosze W';
         SignalStep;
         wW.V();

         status := 'Opuszczam M2';
         SignalStep;
         wMutex2.P();
         Dec(wWriteCount);
         if wWriteCount = 0 then
         begin
              status := 'Jestem ostatnim pisarzem';
              SignalStep;
              wR.V();
         end;

         status := 'Podnosze M2';
         SignalStep;
         wMutex2.V();
    end;

    if logicType = ltFAIR then
    begin
       status := 'Opuszczam O';
       SignalStep;
       fO.P();

       status := 'Opuszczam A';
       SignalStep;
       fA.P();

       status := 'Podnosze O';
       SignalStep;
       fO.V();

       status := 'Piszę';
       for i := 0 to Random(3)+1 do ZeroStep;

       status := 'Podnosze A';
       SignalStep;
       fA.V();
    end;

    // pick logic, pursue it
    CyclesStall := 5+random(8);
  end;
end;

procedure TReader.Execute;
var
  i: Integer;
  prev, current: Cardinal;
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

    if logicType = ltREADERS then
    begin
         status :='Opuszczam M';
         SignalStep;
         rMutex.P();
         status := 'Zwiększam Czytelnikow';
         SignalStep;
         Inc(rReadCount);
         if rReadCount = 1 then
         begin
              status := 'Jestem pierwszym czytelnikiem';
              rWrt.P();
              SignalStep;
         end;
         status := 'Podnosze M';
         SignalStep;
         rMutex.V();
         status := 'Czytam';
         for i := 0 to Random(3)+1 do ZeroStep;

         status := 'Opuszczam M';
         SignalStep;
         rMutex.P();
         status := 'Zmniejszam Czytelnikow';
         SignalStep;
         Dec(rReadCount);
         if rReadCount = 0 then
         begin
              status := 'Jestem ostatnim czytelnikiem';
              rWrt.V();
              SignalStep;
         end;
         status := 'Podnosze M';
         SignalStep;
         rMutex.V();
     end;

    if logicType = ltWRITERS then
    begin
         status := 'Opuszczam M3';
         SignalStep;
         wMutex3.P();

         status := 'Opuszczam R';
         SignalStep;
         wR.P();

         status := 'Opuszczam M1';
         SignalStep;
         wMutex1.P();

         Inc(wReadCount);
         if wReadCount = 1 then
         begin
              status := 'Jestem pierwszym czytelnikiem';
              SignalStep;
              wW.P();
         end;

         status := 'Podnosze M1';
         SignalStep;
         wMutex1.V();
         status := 'Podnosze R';
         SignalStep;
         wR.V();
         status := 'Podnosze M3';
         SignalStep;
         wMutex3.V();

         status := 'Czytam';
         for i := 0 to Random(3)+1 do ZeroStep;

         status := 'Opuszczam M1';
         SignalStep;
         wMutex1.P();


         Dec(wReadCount);
         if wReadCount = 0 then
         begin
              status := 'Jestem ostatnim czytelnikiem';
              SignalStep;
              wW.V();
         end;

         status := 'Podnosze M1';
         SignalStep;
         wMutex1.V();
    end;

    if logicType = ltFAIR then
    begin
         status := 'Opuszczam O';
         SignalStep;
         fO.P();

         status := 'Opuszczam R';
         SignalStep;
         fR.P();

         if nreaders = 0 then
         begin
              status := 'Jako pierwszy opuszczam A';
              SignalStep;
              fA.P();
         end;

         status := 'Zwiekszam il. czytelnikow';
         SignalStep;
         Inc(nreaders);

         status := 'Podnosze O';
         SignalStep;
         fO.V();

         status := 'Podnosze R';
         SignalStep;
         fR.V();

         status := 'Czytam';
         for i := 0 to Random(3)+1 do ZeroStep;

         status := 'Opuszczam R';
         SignalStep;
         fR.P();

         status := 'Zmniejszam il. czytelnikow';
         SignalStep;
         Dec(nreaders);

         if nreaders = 0 then
         begin
              status := 'Podnosze A jako ostatni czytelnik';
              SignalStep;
              fA.V();
         end;

         status := 'Podnosze R';
         SignalStep;
         fR.V();
    end;

    // pick logic, pursue it
    CyclesStall := 5+random(13);
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


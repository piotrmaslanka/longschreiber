unit Unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TForm2 }

  TForm2 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form2: TForm2;

implementation
uses
  Unit1;

{ TForm2 }

procedure TForm2.Button1Click(Sender: TObject);
begin
  logicType := ltREADERS;
  Form2.Close;
end;

procedure TForm2.Button2Click(Sender: TObject);
begin
  logicType := ltWRITERS;
  Form2.Close;
end;

procedure TForm2.Button3Click(Sender: TObject);
begin
  logicType := ltFAIR;
  Form2.Close;
end;

{$R *.lfm}

end.


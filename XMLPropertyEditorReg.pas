unit XMLPropertyEditorReg;

interface

uses DesignIntf, DesignEditors, XMLClientDataSet;

Type  TXMLProperty = Class(TPropertyEditor)
    Public
      Function GetAttributes:  TPropertyAttributes; Override;
      Procedure Edit; Override;
      Function AllEqual: boolean; Override;
      Function  GetValue: string; Override;
      Procedure SetValue (const Value: string); Override;
    End;

procedure Register;


implementation

uses XMLPropertyEditor, SysUtils, Forms, Dialogs, Classes, Controls;

procedure Register;
Begin
  RegisterPropertyEditor(TypeInfo(string),TXMLBaseClientDataSet,'XML',TXMLProperty);
End;

{ TXMLProperty }

function TXMLProperty.GetAttributes: TPropertyAttributes;
begin
  Result := Inherited GetAttributes + [paDialog];
end;

procedure TXMLProperty.Edit;
Var Dlg: TFrm_XMLEdit;
begin
  Dlg := Tfrm_XMLEDIT.Create(Application);
  Try
    Dlg.SM_XMLEdit.Lines.Text := GetStrValue;
    Dlg.ShowModal;
    If Dlg.ModalResult = mrOK Then
    Begin
      TXMLClientDataSet(GetComponent(0)).XML := Dlg.SM_XMLEdit.Lines.Text;
    End;
  Finally
    FreeAndNil(Dlg);
  End;
end;

function TXMLProperty.AllEqual: boolean;
var
  FirstVal: string;
  i: Integer;
begin
  FirstVal := GetStrValue;
  Result := True;
  i := 1;
  while Result and (i < PropCount) do
  begin
    Result := Result and (GetStrValueAt(i) = FirstVal);
    Inc(i);
  end;
end;

function TXMLProperty.GetValue: string;
begin
  Result := GetStrValue;
end;

procedure TXMLProperty.SetValue(const Value: string);
begin
  SetStrValue(Value);
end;


end.

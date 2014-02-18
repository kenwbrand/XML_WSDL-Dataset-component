unit WSDLClientDataSet;

interface

uses Classes, DB, XMLClientDataSet, WSDLNode, SOAPHTTPClient, unit_SoapHelpers, Forms ;

  type
    TWSDLClientDataSet = class(TXMLBaseClientDataSet)
  private
    { Private declarations }
    FHelper: TSoapHelper;
    FActive: Boolean;
    FMethod: String;
    FMethodNumber: Integer;
    FWSDLLocation: String;
    FService: String;
    FPort: String;
    Function GetWSDLLocation: String;
    Procedure SetWSDLLocation(WSDLLocation: String);
    Function GetService: String;
    Procedure SetService(Service: String);
    Function GetPort: String;
    Procedure SetPort(Port: String);
    Function GetMethods: String;
    Procedure SetMethods(Methods: String);
    Procedure SetActive(Value: Boolean); Reintroduce;
    Procedure SetMethodNumber(MethodNumber: Integer);
    Function GetMethodNumber: Integer;
    Procedure BindParams;
  public
    { Public declarations }
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Property SoapHelper: TSoapHelper Read FHelper;
  published
    { Published declarations }
    property DataSetField;
    property Params;
    Property WSDLLocation: String Read GetWSDLLocation Write SetWSDLLocation;
    Property Service: String Read GetService Write SetService;
    Property Port: String Read GetPort Write SetPort;
    Property Method: String Read GetMethods Write SetMethods;
    Property MethodNumber: Integer Read GetMethodNumber Write SetMethodNumber;
    Property Active: Boolean Read FActive Write SetActive;
  end;

procedure Register;

implementation
uses dialogs, SysUtils;

procedure Register;
begin
  RegisterComponents('RSI', [TWSDLClientDataSet]);
end;

{ TWSDLClientDataSet }

procedure TWSDLClientDataSet.BindParams;
Var Cnt: Integer;
begin
  For Cnt := 0 To Params.Count -1 Do
  Begin
    FHelper.SetParameter(Self.Params.Items[Cnt]);
  End;
end;

Constructor TWSDLClientDataSet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHelper := TSoapHelper.Create(Self);
end;

destructor TWSDLClientDataSet.Destroy;
begin
  Self.Active := False;
  FHelper.Free;
  Inherited;
end;

function TWSDLClientDataSet.GetMethodNumber: Integer;
begin
  If Not (Method = '') Then
    Result := FMethodNumber
  Else
    Result := 0;
end;

function TWSDLClientDataSet.GetMethods: String;
begin
  If Not (Port = '') Then
    Result := FMethod
  Else
    Result := '';
end;

function TWSDLClientDataSet.GetPort: String;
begin
  If Not (Service = '') Then
    Result := FPort
  Else
    Result := '';
end;

function TWSDLClientDataSet.GetService: String;
begin
  If Not (WSDLLocation = '') Then
    Result := FService
  Else
    Result := '';
end;

function TWSDLClientDataSet.GetWSDLLocation: String;
begin
  Result := FWSDLLocation;
end;

procedure TWSDLClientDataSet.SetActive(Value: Boolean);
begin
  If (Value) And (FHelper.Method <> '')  Then
  Begin
    BindParams;
    FHelper.ExecuteMethod(FHelper.Method,self.Tag);
    SetXML(FHelper.XML);
  End;
  inherited;
  FActive := Value;
end;

procedure TWSDLClientDataSet.SetMethodNumber(MethodNumber: Integer);
begin
  FHelper.MethodNumber := MethodNumber;
  FMethodNumber := MethodNumber;
  IF Method <> '' Then
  Begin
    Self.Params.Assign(FHelper.Params(Self.Method,MethodNumber));
  End;
end;

procedure TWSDLClientDataSet.SetMethods(Methods: String);
Var ActiveState: Boolean;
begin
  If Methods <> FMethod Then
  Begin
    ActiveState := Self.Active;
    Self.Active := False;
    FHelper.Method := Methods;
    FMethod := Methods;
    Self.MethodNumber := 1;
    Self.Active := ActiveState;
  End;
end;

procedure TWSDLClientDataSet.SetPort(Port: String);
begin
  FHelper.Port := Port;
  FPort := Port;
  FHelper.GetMethods(False);
end;

procedure TWSDLClientDataSet.SetService(Service: String);
begin
  FHelper.Service := Service;
  FService := Service;
  FHelper.GetPorts;
end;

procedure TWSDLClientDataSet.SetWSDLLocation(WSDLLocation: String);
begin
  FHelper.Destroy;
  FHelper := TSoapHelper.Create(Self);
  BindParams;
  Self.Active := False;
  FHelper.WSDLLocation:= WSDLLocation;
  FWSDLLocation := WSDLLocation;
  Try
    FHelper.LoadWSDLDocument(WSDLLocation);
  Except
    FHelper.WSDLLocation:= '';
    Raise ESoapHelperException.Create('WSDLLoaction is Not Valid');
  End;
  FHelper.GetServices;
end;

end.

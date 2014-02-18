unit unit_SoapHelpers;

interface
uses Classes, Sysutils, Dialogs, Variants, DB, XMLDoc, SOAPHTTPClient, WSDLIntf,
     XMLDom, unit_SoapParams, XMLUtil, XMLXForm, WSDLItems, XMLIntf;

Type ESoapHelperException = Class(Exception)
  Public
    Constructor Create(const Msg: String);
End;

Type TSoapHelper = class(TComponent)
  private
    { Private declarations }
    FParams: TSoapParamList;
    FHTTPRio: THTTPRIO; // RemoteInterface returning WSDL Information
    FRemoteInterface: THTTPRIO; // RemoteInterface handling the Remote Procedure Calls.
    FXMLDoc: XMLDoc.TXMLDocument;
    FLoadedMethod: String;
    FLoadedNumber: Integer;
    FExeResult: String;
    FPort: String;
    FService: String;
    FMethod: String;
    FWSDLLocation: String;
    FMethodNumber: Integer;
    FMethodList: TStringList;
    FNSPrefix: String;
    FEXEAddress: String;
    Function IsWSFault(Message: String): Boolean;
    Function RinseSoapFault(RawSoapMsg: String):String;
    Function RinseSoap(RawSoapMsg: String; MethodReturnMsg: String):String;
    Function RinseSoapString(SoapMsg: String; MethodReturnMsg: String):String;
    Function RinseSoapBoolean(SoapMsg: String; MethodReturnMsg: String):String;
    Function RinseSoapArray(SoapMsg: String; MethodReturnMsg: String):String;
    property XMLDocument: XMLDoc.TXMLDocument Read FXMLDoc write FXMLDoc;
    property RemoteInterface: THTTPRIO Read FRemoteInterface write FRemoteInterface;
    Property ExeAddress: String Read FEXEAddress Write FEXEAddress;
    Function DataMsg(MethodName: String;MethodNumber: Integer): TStream;
    Function ParseSoapMsg(SoapMsg,MethodName: String): String;
    Procedure SetXML(XML: String);
    Function WideStrToStrings(WideStrings: TWideStrings; AllowDups: Boolean): TStrings;
    Function GetPort: String;
    Function GetService: String;
    Function GetMethod: String;
    Function GetWSDLLocation: String;
    Function GetMethodNumber: Integer;
    Procedure SetMethodNumber(MethodNumber: Integer);
    Procedure SetWSDLLocation(WSDLLocation: String);
    Procedure SetMethod(Method: String);
    Procedure SetPort(Port: String);
    Procedure SetService(Service: String);
    Function TrimPrefix(Delimitor,Str: String): String;
    Procedure LoadOperationParameters(ProcName: String;ProcNumber: Integer);
    Function GetWSDLMethodNumber(MethodName: String; OverloadNumber: Integer): Integer;
    Function GetOverLoadCount: Integer; OverLoad;
    Function GetTargetNamespacePrefix(NameSpace: String): String;
    Function DTToVT (DataType: TFieldType): TSoapValueType;
  public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;
    Procedure LoadWSDLDocument(WSDLLocation: String);
    Procedure SetParameterValue(Index: Integer; Value: String);
    Procedure SetParameter(Param: TParam);
    Procedure ExecuteMethod(MethodName: String;MethodNumber: Integer);
    Function GetServices: TStrings;
    Function GetPorts: TStrings;
    Function GetMethods(AllowDups: Boolean): TStrings;
    Function Params(MethodName: String; MethodNumber: Integer): TParams;
    Function MethodLoaded(MethodName:String; MethodNumber: Integer): Boolean;
    Property XML: String Read FExeResult Write SetXML;
    property HTTPRio: THTTPRIO Read FHTTPRio write FHTTPRio;
    Property Port: String read GetPort Write SetPort;
    Property Service: String Read GetService Write SetService;
    Property Method: String Read GetMethod Write SetMethod;
    Property MethodNumber: Integer Read GetMethodNumber Write SetMethodNumber;
    Property WSDLLocation: String Read GetWSDLLocation Write SetWSDLLocation;
    Property OverLoadCount: Integer Read GetOverloadCount;

end;

implementation

constructor TSoapHelper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FParams := TSoapParamList.Create;
  FHTTPRio := THTTPRio.Create(Self);
  FRemoteInterface := THTTPRio.Create(Self);
  FXMLDoc := XMLDoc.TXMLDocument.Create(Self);
  FMethodList := TStringList.Create;
  FMethodNumber := 1;
  FNSPrefix := '';
end;

destructor TSoapHelper.Destroy;
begin
  FParams.Free;
  FHTTPRio.Free;
  FXMLDoc.Free;
  FRemoteInterface.Free;
  FMethodList.Free;
  inherited;
end;

function TSoapHelper.GetMethod: String;
begin
  If VarIsNull(FMethod) Then
    Result := ''
  Else
    Result := FMethod;
end;

function TSoapHelper.GetMethodNumber: Integer;
begin
  Result := FMethodNumber;
end;

function TSoapHelper.GetTargetNamespacePrefix(NameSpace: String): String;
var
  XMLNode: IXMLNode;
begin
  Result := '';
  XMLNode := FHTTPRio.WSDLItems.Definition.FindNamespaceDecl(NameSpace);
  if XMLNode <> nil then
    Result := ExtractLocalName(XMLNode.NodeName);
end;

function TSoapHelper.GetMethods(AllowDups: Boolean): TStrings;
Var Methods: TWideStrings;
  Cnt: Integer;
begin
  If Not(Self.Port = '') Then
  Begin
    FMethodList.Clear;
    Methods := TWideStrings.Create;
    FHTTPRio.WSDLItems.GetOperations(Self.Port,Methods,False);
    for Cnt := 0 to Methods.Count - 1 do
      FMethodList.Add(Methods.Strings[Cnt]+'='+IntToStr(Cnt));
    Result := WideStrToStrings(Methods,AllowDups);
  End
  Else
    Raise ESoapHelperException.Create('Port must be set before Methods can be returned');
end;


function TSoapHelper.GetOverLoadCount: Integer;
var
  Cnt: Integer;
  MethodOccurenceCount: Integer;
begin
  MethodOccurenceCount := 0;
  For Cnt := 0 to FMethodList.Count - 1 do
  Begin
    if FMethodList.Names[Cnt] = FLoadedMethod then
      Inc(MethodOccurenceCount);
  End;
  Result := MethodOccurenceCount;
end;

Function TSoapHelper.Params(MethodName: String; MethodNumber: Integer): TParams;
Var Cnt: Integer;
    Param: DB.TParam;
    Params: TParams;
begin

  Params := TParams.Create(Self);
  Params.Clear;
  If (FLoadedMethod <> MethodName) And (FLoadedMethod <> '') Then
    LoadOperationParameters(MethodName,GetWSDLMethodNumber(MethodName,MethodNumber));
  For Cnt := 0 To Fparams.Count -1 Do
  Begin
    Param := TParam.Create(Params);
    Param.Name := Fparams.ReadParam(Cnt).Name;
    Param.Bound := True;
    Param.ParamType := ptInput;
    Case FParams.ReadParam(Cnt).ParamType OF
      vtString:
      Begin
        Param.DataType := ftString;
        Param.Size := 100;
      End;
      vtInteger:
      Begin
        Param.DataType := ftInteger;
        Param.Precision := 100;
      End;
      vtArray:
        Param.DataType := ftArray;
      vtBoolean:
        Param.DataType := ftBoolean;
      vtLong:
        Param.DataType := ftLargeint;
      Else
        Param.DataType := ftString;
    End;
    Param.ParamType := ptInput;
    Param.Value := FParams.ReadParam(Cnt).Value;
    Params.AddParam(Param);
  End;
  FLoadedMethod := MethodName;
  FLoadedNumber := MethodNumber;
  Result := Params;
end;

function TSoapHelper.GetPort: String;
begin
  Result := FPort;
end;

function TSoapHelper.GetPorts: TStrings;
Var Ports: TWideStrings;
begin
  If Not(Self.Service = '') Then
  Begin
    Ports := TWideStrings.Create;
    HTTPRio.WsdlItems.GetPortTypes(Ports,true,false);
    Result := WideStrToStrings(Ports,False);
  End
  Else
    Raise ESoapHelperException.Create('Service must be set before Port can be set');
end;

function TSoapHelper.GetService: String;
begin
   Result := FService;
end;

function TSoapHelper.GetServices: TStrings;
Var Services: TWideStrings;
begin
  If Not(HttpRio.URL = '') Then
  Begin
    Services := TWideStrings.Create;
    HTTPRio.WsdlItems.GetServices(Services,false);
    Result := WideStrToStrings(Services,False);
  End
  Else
    Raise ESoapHelperException.Create('WSDLLocation must be set before Service can be set ');
end;

function TSoapHelper.GetWSDLLocation: String;
begin
  Result := FWSDLLocation;
end;

function TSoapHelper.GetWSDLMethodNumber(MethodName: String;
  OverloadNumber: Integer): Integer;
Var Cnt: Integer;
    MethodList: TStringList;
begin
  Try
    MethodList := TStringList.Create;
    For Cnt := 0 To FMethodList.Count -1 Do
    Begin
      if FMethodList.Names[Cnt] = MethodName Then
        MethodList.Add(FMethodList.Strings[Cnt]);
    End;
    IF MethodList.Count >= OverLoadNumber Then
    Begin
      Result := StrToInt(MethodList.ValueFromIndex[OverLoadNumber -1]);
    End
    Else
      Result := 0;
  Except
    On E: Exception Do
      Result := 0;
  End;
end;

procedure TSoapHelper.LoadOperationParameters(ProcName: String; ProcNumber: Integer);
Var OpsEnum: Integer;
    PartNames: TWideStrings;
    TmpList: TStringList;
    ParamType: String;
    MessageName: String;
begin
  TmpList := TStringList.Create;
  TmpList.add(ProcName);
  PartNames := TWideStrings.Create;
  FHTTPRio.WSDLItems.GetPartsForOperation(Self.Port,ProcName,ProcNumber,PartNames);
  MessageName := TrimPrefix(':',FHTTPRio.WSDLItems.GetOperationNode(Self.Port,ProcName).ChildNodes.FindNode('input').Attributes['message']);
  FParams.Clear;
  For OpsEnum := 0 TO PartNames.Count -1 Do
  Begin
    ParamType := FHTTPRio.WSDLItems.GetPartNode(MessageName,PartNames.Strings[OpsEnum]).Attributes['type'];
    FParams.AddParam(PartNames.Strings[OpsEnum],'',StrToSoapValue(ParamType));
  End;
end;

procedure TSoapHelper.LoadWSDLDocument(WSDLLocation: String);
begin
  If NOT (Trim(WSDLLocation) = '') Then
  Begin
    HTTPRio.URL := WSDLLocation;
    HTTPRio.WSDLItems.Load(WSDLLocation);
    FNSPrefix := GetTargetNamespacePrefix(HTTPRio.WSDLItems.TargetNamespace);
  End;
end;

function TSoapHelper.MethodLoaded(MethodName: String;
  MethodNumber: Integer): Boolean;
begin
  IF (MethodName <> FLoadedMethod) OR (MethodNumber <> FLoadedNumber) Then
    Result := False
  Else
    Result := True;
end;

function TSoapHelper.IsWSFault(Message: String): Boolean;
begin
  Result := NOT (FXMLDoc.DOMDocument.getElementsByTagName('faultcode').length = 0);
end;

function TSoapHelper.RinseSoapArray(SoapMsg, MethodReturnMsg: String): String;
Var ReturnNode: IDomNode;
    TempXMLDoc: XMLDoc.TXMLDocument;
begin
  TempXMLDoc := XMLDoc.TXMLDocument.Create(self);
  TempXMLDoc.Active := True;
  ReturnNode := FXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0];
  TempXMLDoc.DocumentElement := TempXMLDoc.CreateElement('DataSet','');
  TempXMLDoc.DocumentElement.AddChild(MethodReturnMsg);
  TempXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0].appendChild(ReturnNode);
  Result := TempXMLDoc.XML.Text;
end;

function TSoapHelper.RinseSoapBoolean(SoapMsg: String; MethodReturnMsg: String): String;
Var ReturnNode: IDomNode;
    TempXMLDoc: XMLDoc.TXMLDocument;
begin
  TempXMLDoc := XMLDoc.TXMLDocument.Create(self);
  TempXMLDoc.Active := True;
  ReturnNode := FXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0].firstchild;
  TempXMLDoc.DocumentElement := TempXMLDoc.CreateElement('DataSet','');
  TempXMLDoc.DocumentElement.AddChild(MethodReturnMsg);
  TempXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0].appendChild(ReturnNode);
  Result := TempXMLDoc.XML.Text;
end;

function TSoapHelper.RinseSoapString(SoapMsg: String; MethodReturnMsg: String): String;
Var ReturnNode: IDomNode;
    TempXMLDoc: XMLDoc.TXMLDocument;
begin
  TempXMLDoc := XMLDoc.TXMLDocument.Create(self);
  TempXMLDoc.Active := True;
  ReturnNode := FXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0].firstchild;
  If POS('<?xml',ReturnNode.nodeValue) = 0 Then
  Begin
    TempXMLDoc.DocumentElement := TempXMLDoc.CreateElement('DataSet','');
    TempXMLDoc.DocumentElement.AddChild(MethodReturnMsg);
    TempXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0].appendChild(ReturnNode);
  End
  Else
    TempXMLDoc.XML.Text := ReturnNode.nodeValue;
  Result := TempXMLDoc.XML.Text;
end;

procedure TSoapHelper.SetMethod(Method: String);
begin
  FMethod := Method;
end;

procedure TSoapHelper.SetMethodNumber(MethodNumber: Integer);
begin
  If Not (MethodNumber = 0) Then
    FMethodNumber := MethodNumber;
end;

procedure TSoapHelper.SetParameter(Param: TParam);
Var ParamIndex: Integer;
begin
  ParamIndex := FParams.ParamIndex(Param.Name);
  If (ParamIndex > -1) Then
  Begin
    FParams.UpdateParam(ParamIndex,Param.Name,Param.Value,DTToVT(param.DataType));
  End
  Else
  Begin
    FParams.AddParam(Param.Name,Param.Value,DTtoVT(Param.DataType));
  End;
end;

procedure TSoapHelper.SetParameterValue(Index: Integer; Value: String);
begin
  IF (Index <= FParams.Count) And (FParams.Count > 0) Then
  Begin
    FParams.UpdateParam(Index,FParams.ReadParam(index).Name,Value,FParams.ReadParam(index).ParamType);
  End ;
end;

procedure TSoapHelper.SetPort(Port: String);
var
  PortsWS: TWideStrings;
begin
  PortsWS := TWideStrings.Create;
  FPort := Port;
  // we should now have service and port we can now find the port/service address
  HTTPRio.WSDLItems.GetportsForService(Service,PortsWS);
  ExeAddress := HTTPRio.WSDLItems.GetSoapAddressForServicePort(Service,PortsWS.Strings[0]);
end;

procedure TSoapHelper.SetService(Service: String);
begin
  FService := Service;
end;

procedure TSoapHelper.SetWSDLLocation(WSDLLocation: String);
begin
  FWSDLLocation := WSDLLocation;
end;

procedure TSoapHelper.SetXML(XML: String);
begin
  Self.XMLDocument.LoadFromXML(FExeResult);
end;

function TSoapHelper.TrimPrefix(Delimitor, Str: String): String;
Var DelResult: String;
begin
  DelResult := Str;
  Delete(DelResult,1,Pos(Delimitor,Str));
  Result := DelResult;
end;

function TSoapHelper.WideStrToStrings(WideStrings: TWideStrings; AllowDups: Boolean): TStrings;
Var Cnt: Integer;
    Strings: TStringList;
begin
  Strings := TStringList.Create;
  Strings.Sorted := True;
  If Not AllowDups Then
    Strings.Duplicates := dupIgnore;
  For Cnt := 0 To WideStrings.Count -1 Do
  Begin
    Strings.Add(WideStrings.Strings[Cnt]);
  End;
  Result := Strings;
end;

function TSoapHelper.RinseSoap(RawSoapMsg: String; MethodReturnMsg: String): String;
Var NewMsg: String;
    MethodReturnType: String;
begin
  Try
    MethodReturnType := FXMLDoc.DOMDocument.getElementsByTagName(MethodReturnMsg).item[0].attributes.getNamedItem('xsi:type').nodeValue;  //item[0].nodevalue;
    If (MethodReturnType = 'xsd:string') Then
      NewMsg := RinseSoapString(RawSoapMsg,MethodReturnMsg)
    Else If (MethodReturnType = 'xsd:boolean') Then
      NewMsg := RinseSoapBoolean(RawSoapMsg,MethodReturnMsg)
    Else If (MethodReturnType = 'soapenc:Array') Then
      NewMsg := RinseSoapArray(RawSoapMsg,MethodReturnMsg)
    Else
      NewMsg := RawSoapMsg;
    Result := NewMsg;
  Except
    On E: Exception Do
      Result := RawSoapMsg;
  End;
end;

function TSoapHelper.RinseSoapFault(RawSoapMsg: String): String;
Var FaultCode,FaultString,Detail: IDomNode;
    TempXMLDoc: XMLDoc.TXMLDocument;
begin
  TempXMLDoc := XMLDoc.TXMLDocument.Create(self);
  TempXMLDoc.Active := True;
  FaultCode := FXMLDoc.DOMDocument.getElementsByTagName('faultcode').item[0].firstchild;
  FaultString := FXMLDoc.DOMDocument.getElementsByTagName('faultstring').item[0].firstchild;
  Detail := FXMLDoc.DOMDocument.getElementsByTagName('detail').item[0].firstchild;
  TempXMLDoc.DocumentElement := TempXMLDoc.CreateElement('DataSet','');
  TempXMLDoc.DocumentElement.AddChild('faultcode');
  TempXMLDoc.DocumentElement.AddChild('faultstring');
  TempXMLDoc.DocumentElement.AddChild('detail');
  TempXMLDoc.DOMDocument.getElementsByTagName('faultcode').item[0].appendChild(FaultCode);
  TempXMLDoc.DOMDocument.getElementsByTagName('faultstring').item[0].appendChild(FaultString);
  TempXMLDoc.DOMDocument.getElementsByTagName('detail').item[0].appendChild(Detail);
  Result := TempXMLDoc.XML.Text;
end;

function TSoapHelper.ParseSoapMsg(SoapMsg,MethodName: String): String;
Var ProcOutputMessageName, ProcOutputName: String;
begin
  ProcOutputMessageName := FHTTPRio.WSDLItems.GetOperationNode(Self.Port,MethodName).ChildNodes.FindNode('output').Attributes['message'];
  ProcOutputMessageName := TrimPrefix(':',ProcOutputMessageName);
  ProcOutputName := FHTTPRio.WSDLItems.GetMessageNode(ProcOutputMessageName).ChildNodes.FindNode('part').Attributes['name'];
  IF IsWSFault(SoapMsg) Then
    Result := RinseSoapFault(SoapMsg)
  Else
    Result :=  RinseSoap(SoapMsg,ProcOutputName);
end;

function TSoapHelper.DataMsg(MethodName: String;MethodNumber: Integer): TStream;
Var SS: TSTringStream;
    BuildMsg,ParamName,ParamType,ParamValue: String;
    NameSpace: String;
    ParamEnum: Integer;
begin
  nameSpace := FHTTPRio.WSDLItems.GetSoapBodyNamespace(Self.Port);
  BuildMsg := '<?xml version="1.0"?>'+Chr(13)+Chr(10)
  + '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/">'+Chr(13)+Chr(10)
  + '<SOAP-ENV:Body SOAP-ENV:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'+Chr(13)+Chr(10)
  + ' <NS1:'+MethodName+' xmlns:NS1="'+NameSpace+'">'+Chr(13)+Chr(10);
//  + ' <NS1:'+MethodName+' xmlns:NS1="http://www.revenuesolutionsinc.com">'+Chr(13)+Chr(10);
  For ParamEnum := 0 TO FParams.Count -1 Do
  Begin
    ParamName := FParams.ReadParam(ParamEnum).Name;
    ParamType := SoapValueToStr(FParams.ReadParam(ParamEnum).ParamType);
    ParamValue := FParams.ReadParam(ParamEnum).Value;

    BuildMsg := BuildMsg
    + '  <' + ParamName
    + ' xsi:type="' + ParamType + '">';
    BuildMsg := BuildMsg
    + ParamValue;
    BuildMsg := BuildMsg
    + '</' + ParamName + '>'+Chr(13)+Chr(10);
  End;
  BuildMsg := BuildMsg
  + '</NS1:'+MethodName+'>'+Chr(13)+Chr(10)
  + '</SOAP-ENV:Body>'+Chr(13)+Chr(10)
  + '</SOAP-ENV:Envelope>'+Chr(13)+Chr(10);
  SS := TStringStream.Create(BuildMsg);
  Result := SS;
end;

procedure TSoapHelper.ExecuteMethod(MethodName: String;MethodNumber: Integer);
Var TempStream: TStringStream;
begin
  RemoteInterface.URL := ExeAddress;
  TempStream := TStringStream.Create('');
  RemoteInterface.WebNode.Execute(Self.DataMsg(MethodName,MethodNumber),TempStream);
  FExeResult := TempStream.DataString;
  TempStream.Free;
  Self.XMLDocument.LoadFromXML(FExeResult);
  FExeResult := Self.ParseSoapMsg(FExeResult,MethodName);
end;

Function TSoapHelper.DTToVT (DataType: TFieldType): TSoapValueType;
  Begin
    Case DataType Of
      ftUnknown:
        Result := vtString;
      ftString:
        Result := vtString;
      ftSmallint:
        Result := vtInteger;
      ftInteger:
        Result := vtInteger;
      ftWord:
        Result := vtInteger;
      ftBoolean:
        Result := vtBoolean;
      ftFloat:
        Result := vtString;
      ftCurrency:
        Result := vtString;
      ftBCD:
        Result := vtString;
      ftDate:
        Result := vtString;
      ftTime:
        Result := vtString;
      ftDateTime:
        Result := vtString;
      ftBytes:
        Result := vtInteger;
      ftVarBytes:
        Result := vtInteger;
      ftAutoInc:
        Result := vtString;
      ftBlob:
        Result := vtString;
      ftMemo:
        Result := vtString;
      ftGraphic:
        Result := vtString;
      ftFmtMemo:
        Result := vtString;
      ftParadoxOle:
        Result := vtString;
      ftDBaseOle:
        Result := vtString;
      ftTypedBinary:
        Result := vtString;
      ftCursor:
        Result := vtString;
      ftFixedChar:
        Result := vtString;
      ftWideString:
        Result := vtString;
      ftLargeint:
        Result := vtLong;
      ftADT:
        Result := vtString;
      ftArray:
        Result := vtArray;
      ftReference:
        Result := vtString;
      ftDataSet:
        Result := vtString;
      ftOraBlob:
        Result := vtString;
      ftOraClob:
        Result := vtString;
      ftVariant:
        Result := vtString;
      ftInterface:
        Result := vtString;
      ftIDispatch:
        Result := vtString;
      ftGuid:
        Result := vtString;
      ftTimeStamp:
        Result := vtString;
      ftFMTBcd:
        Result := vtString;
//      ftFixedWideChar:
//        Result := vtString;
//      ftWideMemo:
//        Result := vtString;
//      ftOraTimeStamp:
//        Result := vtString;
//      ftOraInterval:
//        Result := vtString;
      Else
        Result := vtString;
  End;
End;


{ ESoapHelperException }

constructor ESoapHelperException.Create(const Msg: String);
begin
  Inherited;
end;

end.

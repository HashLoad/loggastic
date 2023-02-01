unit Providers.Log;

interface

uses System.JSON, REST.JSON, System.Net.HTTPClientComponent, System.Threading, System.SysUtils, System.DateUtils, Horse,
  REST.Client, REST.Types, System.Generics.Collections;

const
  DATE_HEADER = '_@DATE';

type
  TProviderLogResponse = class
  private
    FBody: string;
    FDate: TDateTime;
    FReasonString: string;
    FStatusCode: Integer;
    FContentType: string;
    FContentLength: Integer;
  public
    property Date: TDateTime read FDate write FDate;
    property ReasonString: string read FReasonString write FReasonString;
    property StatusCode: Integer read FStatusCode write FStatusCode;
    property ContentType: string read FContentType write FContentType;
    property ContentLength: Integer read FContentLength write FContentLength;
    property Body: string read FBody write FBody;
    function ToJSON: TJSONObject;
    constructor Create(const AResponse: THorseResponse); overload;
    constructor Create(AStatusCode: Integer; AError, ADescription: string); overload;
  end;

  TProviderLogRequest = class
  private
    FDate: TDateTime;
    FMethod: string;
    FContentType: string;
    FParams: TJSONObject;
    FBody: string;
    FContentLength: Integer;
    function DictionaryToJsonObject(ADictionary: TDictionary<string, string>): TJSONObject;
  public
    property Date: TDateTime read FDate write FDate;
    property Method: string read FMethod write FMethod;
    property ContentType: string read FContentType write FContentType;
    property ContentLength: Integer read FContentLength write FContentLength;
    property Params: TJSONObject read FParams write FParams;
    property Body: string read FBody write FBody;
    function ToJSON: TJSONObject;
    constructor Create(const ARequest: THorseRequest; AStartDate: TDateTime);
  end;

  TProviderLogGeneral = class
  private
    FBasePath: string;
    FServerHost: string;
    FPathInfo: string;
    FSession: TJSONObject;
    procedure SetSession(const ARequest: THorseRequest);
  public
    property BasePath: string read FBasePath write FBasePath;
    property ServerHost: string read FServerHost write FServerHost;
    property PathInfo: string read FPathInfo write FPathInfo;
    property Session: TJSONObject read FSession write FSession;
    function ToJSON: TJSONObject;
    constructor Create(const ARequest: THorseRequest);
  end;

  TProviderLog = class
  private
  class var
    FElasticSearchUrl: string;
  private
    FRequest: TProviderLogRequest;
    FResponse: TProviderLogResponse;
    FGeneral: TProviderLogGeneral;
  public
    class property ElasticSearchUrl: String read FElasticSearchUrl write FElasticSearchUrl;
    property General: TProviderLogGeneral read FGeneral write FGeneral;
    property Request: TProviderLogRequest read FRequest write FRequest;
    property Response: TProviderLogResponse read FResponse write FResponse;
    procedure SendLog;
    function ToJSON: TJSONObject;
    constructor Create(const ARequest: THorseRequest; const AResponse: THorseResponse; AStartDate: TDateTime); overload;
    constructor Create(const ARequest: THorseRequest; const AResponse: THorseResponse; AError: string; AStartDate: TDateTime); overload;
    destructor Destroy; override;
  end;

procedure Log(const ARequest: THorseRequest; const AResponse: THorseResponse; AStartDate: TDateTime); overload;
procedure Log(const ARequest: THorseRequest; const AResponse: THorseResponse; AError: string; AStartDate: TDateTime); overload;

implementation

uses System.NetEncoding, System.Classes, IdHTTPWebBrokerBridge, IdHTTPHeaderInfo;

type
  TIdHTTPAppRequestHelper = class helper for TIdHTTPAppRequest
  public
    function GetRequestInfo: TIdEntityHeaderInfo;
    function GetHeadersJSON: TJSONObject;
  end;

procedure Log(const ARequest: THorseRequest; const AResponse: THorseResponse; AStartDate: TDateTime);
var
  LLog: TProviderLog;
begin
  LLog := TProviderLog.Create(ARequest, AResponse, AStartDate);
  try
    LLog.SendLog;
  finally
    LLog.Free;
  end;
end;

procedure Log(const ARequest: THorseRequest; const AResponse: THorseResponse; AError: string; AStartDate: TDateTime); overload;
var
  LLog: TProviderLog;
begin
  LLog := TProviderLog.Create(ARequest, AResponse, AError, AStartDate);
  try
    LLog.SendLog;
  finally
    LLog.Free;
  end;
end;

{ TProviderLog }

constructor TProviderLog.Create(const ARequest: THorseRequest; const AResponse: THorseResponse; AStartDate: TDateTime);
begin
  FGeneral := TProviderLogGeneral.Create(ARequest);
  FRequest := TProviderLogRequest.Create(ARequest, AStartDate);
  FResponse := TProviderLogResponse.Create(AResponse);
end;

constructor TProviderLog.Create(const ARequest: THorseRequest; const AResponse: THorseResponse; AError: string; AStartDate: TDateTime);
begin
  FGeneral := TProviderLogGeneral.Create(ARequest);
  FRequest := TProviderLogRequest.Create(ARequest, AStartDate);
  FResponse := TProviderLogResponse.Create(AResponse.Status, AError, AResponse.RawWebResponse.Content);
end;

destructor TProviderLog.Destroy;
begin
  FGeneral.Free;
  FRequest.Free;
  FResponse.Free;
end;

procedure TProviderLog.SendLog;
var
  LTask: ITask;
  LStringLog: string;
  LLog: TJSONObject;
begin
  LLog := Self.ToJSON;
  try
    LStringLog := LLog.ToJSON;
  finally
    LLog.Free;
  end;

  LTask := TTask.Create(
    procedure
    var
      LRESTClient: TRESTClient;
      LRESTRequest: TRESTRequest;
      LRESTResponse: TRESTResponse;
      LBody: TJSONObject;
    begin
      try
        LRESTClient := TRESTClient.Create(FElasticSearchUrl);
        LRESTRequest := TRESTRequest.Create(nil);
        LRESTResponse := TRESTResponse.Create(nil);
        try
          LBody := TJSONObject(TJSONObject.ParseJSONValue(LStringLog));
          try
            LRESTRequest.Client := LRESTClient;
            LRESTRequest.Response := LRESTResponse;
            LRESTRequest.Method := rmPOST;
            LRESTRequest.Params.AddBody(LBody);
            LRESTRequest.Execute;
          finally
            LBody.Free;
          end;
        finally
          LRESTClient.Free;
          LRESTRequest.Free;
          LRESTResponse.Free;
        end;
      except
      end;
    end);

  LTask.Start;
end;

function TProviderLog.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('general', FGeneral.ToJSON);
  Result.AddPair('request', FRequest.ToJSON);
  Result.AddPair('response', FResponse.ToJSON);
end;

procedure TProviderLogGeneral.SetSession(const ARequest: THorseRequest);
const
  JWT_PAYLOAD = 1;
var
  LPayloadEncoded, LPayloadDecoded, LToken: string;
begin
  LToken := ARequest.Headers['X-Authorization'];

  if not LToken.IsEmpty then
  begin
    LToken := LToken.Replace('bearer ', '', [rfIgnoreCase]);
    LPayloadEncoded := LToken.Split(['.'])[JWT_PAYLOAD];
    LPayloadDecoded := TNetEncoding.Base64.Decode(LPayloadEncoded);
    FSession := TJSONObject(TJSONObject.ParseJSONValue(LPayloadDecoded));
  end
  else
    FSession := TJSONObject.Create;
end;

function TProviderLogGeneral.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('basePath', FBasePath);
  Result.AddPair('serverHost', FServerHost);
  Result.AddPair('pathInfo', FPathInfo);
  Result.AddPair('session', FSession);
end;

{ TProviderLogGeneral }

constructor TProviderLogGeneral.Create(const ARequest: THorseRequest);
begin
  FServerHost := ARequest.RawWebRequest.Host;
  FBasePath := ARequest.RawWebRequest.PathInfo;
  FPathInfo := ARequest.RawWebRequest.PathInfo;
  SetSession(ARequest);
end;

{ TProviderLogRequest }

constructor TProviderLogRequest.Create(const ARequest: THorseRequest; AStartDate: TDateTime);
begin
  FDate := AStartDate;
  FMethod := ARequest.RawWebRequest.Method;
  FContentType := ARequest.RawWebRequest.ContentType;
  FParams := TJSONObject.Create;

  FParams.AddPair('querys', DictionaryToJsonObject(ARequest.Query.Dictionary));
  FParams.AddPair('params', DictionaryToJsonObject(ARequest.Params.Dictionary));

  if ARequest.RawWebRequest.InheritsFrom(TIdHTTPAppRequest) then
    FParams.AddPair('headers',  TIdHTTPAppRequest(ARequest.RawWebRequest).GetHeadersJSON);

  if FContentType = 'application/json' then
    FBody := ARequest.Body;

  FContentLength := FBody.Length;
end;

function TProviderLogRequest.DictionaryToJsonObject(ADictionary: TDictionary<string, string>): TJSONObject;
var
  LPair: TPair<string, string>;
begin
  Result := TJSONObject.Create;
  for LPair in ADictionary do
    Result.AddPair(LPair.Key, LPair.Value);
end;

function TProviderLogRequest.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('date', DateToISO8601(FDate));
  Result.AddPair('method', FMethod);
  Result.AddPair('contentType', FContentType);
  Result.AddPair('contentLength', TJSONNumber.Create(FContentLength));
  Result.AddPair('params', FParams);
  Result.AddPair('body', FBody);
end;

{ TProviderLogResponse }

constructor TProviderLogResponse.Create(const AResponse: THorseResponse);
begin
  FDate := Now;
  FReasonString := AResponse.RawWebResponse.ReasonString;
  FStatusCode := AResponse.RawWebResponse.StatusCode;
  FContentType := AResponse.RawWebResponse.ContentType;

  if FContentType = 'application/json' then
    FBody := AResponse.RawWebResponse.Content;

  FContentLength := AResponse.RawWebResponse.ContentLength;
end;

constructor TProviderLogResponse.Create(AStatusCode: Integer; AError, ADescription: string);
var
  LBody: TJSONObject;
begin
  FDate := Now;
  FReasonString := 'Error';
  FStatusCode := AStatusCode;
  FContentType := 'application/json';

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('error', AError);
    LBody.AddPair('description', ADescription);
    FBody := LBody.ToJSON;
    FContentLength := FBody.Length;
  finally
    LBody.Free;
  end;
end;

function TProviderLogResponse.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('date', DateToISO8601(FDate));
  Result.AddPair('reasonString', FReasonString);
  Result.AddPair('statusCode', TJSONNumber.Create(FStatusCode));
  Result.AddPair('contentType', FContentType);
  Result.AddPair('contentLength', TJSONNumber.Create(FContentLength));
  Result.AddPair('body', FBody);
end;

{ TIdHTTPAppRequestHelper }

function TIdHTTPAppRequestHelper.GetHeadersJSON: TJSONObject;
var
  LKey, LValue, LHeader: string;
  LPosSeparator: Integer;
begin
  Result := TJSONObject.Create;
  for LHeader in GetRequestInfo.RawHeaders do
  begin
    LPosSeparator := Pos(':', LHeader);
    LKey := Copy(LHeader, 0, LPosSeparator - 1);
    LValue := Copy(LHeader, LPosSeparator + 1, LHeader.Length - LPosSeparator);
    Result.AddPair(LowerCase(LKey), Trim(LValue));
  end;
end;

function TIdHTTPAppRequestHelper.GetRequestInfo: TIdEntityHeaderInfo;
begin
  Result := FRequestInfo;
end;

end.

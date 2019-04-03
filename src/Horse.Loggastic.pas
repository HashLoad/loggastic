unit Horse.Loggastic;

interface

uses
  Horse, Providers.Log;

function Loggastic(AElasticSearchUrl: string): THorseCallback;

implementation

uses
  System.SysUtils;

function Loggastic(AElasticSearchUrl: string): THorseCallback;
begin
  TProviderLog.ElasticSearchUrl := AElasticSearchUrl;

  Result := procedure(AReq: THorseRequest; ARes: THorseResponse; ANext: TProc)
    begin
      try
        ANext();
        Log(AReq, ARes);
      except
        on E: Exception do
        begin
          Log(AReq, ARes, E.Message);
          raise e;
        end;
      end;
    end;
end;

end.

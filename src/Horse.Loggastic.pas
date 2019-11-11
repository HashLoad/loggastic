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
        AReq.Headers.AddOrSetValue(DATE_HEADER, DateTimeToStr(Now));
        ANext();
        Log(AReq, ARes);
      except
        on E: Exception do
        begin
          if not E.InheritsFrom(EHorseCallbackInterrupted) then
            Log(AReq, ARes, E.Message);
          raise;
        end;
      end;
    end;
end;

end.

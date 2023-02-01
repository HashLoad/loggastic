unit Horse.Loggastic;

interface

uses Horse, Providers.Log;

function Loggastic(AElasticSearchUrl: string): THorseCallback;

implementation

uses System.SysUtils;

function Loggastic(AElasticSearchUrl: string): THorseCallback;
begin
  TProviderLog.ElasticSearchUrl := AElasticSearchUrl;

  Result := procedure(AReq: THorseRequest; ARes: THorseResponse; ANext: TProc)
    var
      LStartDate: TDateTime;
    begin
      LStartDate := Now;
      try
        ANext();
        Log(AReq, ARes, LStartDate);
      except
        on E: Exception do
        begin
          if not E.InheritsFrom(EHorseCallbackInterrupted) then
            Log(AReq, ARes, E.Message, LStartDate);
          raise;
        end;
      end;
    end;
end;

end.

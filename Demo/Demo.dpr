program Demo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Horse,
  Horse.Loggastic in '..\src\Horse.Loggastic.pas',
  Providers.Log in '..\src\Providers\Providers.Log.pas';

var
  App: THorse;

begin
  App := THorse.Create;
  try
    //See output on https://ptsv2.com/t/39fiw-1573504844
    App.Use(Loggastic('https://ptsv2.com/t/39fiw-1573504844/post'));

    App.Get('/', procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('Hello')
    end);

    App.Start;

  finally
    App.Free;
  end;
end.

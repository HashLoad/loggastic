program Demo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  Horse,
  Horse.Loggastic in '..\src\Horse.Loggastic.pas',
  Providers.Log in '..\src\Providers\Providers.Log.pas';

begin
  //See output on https://ptsv2.com/t/39fiw-1573504844
  THorse.Use(Loggastic('https://ptsv2.com/t/39fiw-1573504844/post'));

  THorse.Get('/',
    procedure(Res: THorseResponse)
    begin
      Res.Send('Hello');
    end);

  THorse.Listen;
end.

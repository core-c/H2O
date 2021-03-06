unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Buttons, ImgList, ComCtrls;

const
  MAX_DROPS = 100000;
  ColorWater = $0000FF00;
  DYNAMITE_RADIUS = 20;   //pixels
  MAX_WATERCOLUMN = 20; //pixels

  // map flags
  mEmpty   = -2;
  mTerrain = -1;
  mWater   = 0;

type
  TDrop = record
    X, Y: integer;
  end;

  TPlacing = (pNone, pDynamite, pStick);

  TForm1 = class(TForm)
    BMP: TImage;
    BMPcopy: TImage;
    TimerRun: TTimer;
    bStart: TButton;
    lDropCount: TLabel;
    rgMethod: TRadioGroup;
    bDynamite: TBitBtn;
    bStick: TBitBtn;
    ImageList: TImageList;
    TimerDynamite: TTimer;
    bFlow: TButton;
    tbWaterColumn: TTrackBar;
    Label1: TLabel;
    cbLeaveScreen: TCheckBox;
    tbEraseRadius: TTrackBar;
    Label2: TLabel;
    imgStick: TImage;
    procedure FormCreate(Sender: TObject);
    procedure TimerRunTimer(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure bStartClick(Sender: TObject);
    procedure BMPMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BMPMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure bDynamiteClick(Sender: TObject);
    procedure bStickClick(Sender: TObject);
    procedure TimerDynamiteTimer(Sender: TObject);
    procedure bFlowClick(Sender: TObject);
    procedure BMPMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    drops: array[0..MAX_DROPS-1] of TDrop;
    Map: array of array of integer;
    CountDrops: integer;
    MaxX, MaxY, CenterX: integer;
    SwapLeftRight,
    DoFlow: boolean;       // water/zand laten vallen
    WaterColumn: integer;  // de breedte van de waterval
    Placing: TPlacing;     // dyna of stick aan het plaatsen
    DynamitePos, StickPos: TPoint;
    procedure InitMap;
    procedure ClearMap;
    procedure InitDrops;
    procedure AddDrop;
    procedure MoveDrops;  // drops loop
    procedure MoveDrops2; // map search loop
    procedure RenderDrops;
    function IsValid(nx,ny:integer): boolean;
    function IsWater(nx,ny:integer): boolean;
    function IsEmpty(nx,ny:integer): boolean;
    function IsTerrain(nx,ny:integer): boolean;
    procedure EmptyCircle(X,Y,Radius: integer);
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  BMP.Picture.LoadFromFile('level0.bmp');
  BMPcopy.Picture.LoadFromFile('level0.bmp');
  BMPcopy.Visible := false;
  imgStick.Visible := false;
  ImageList.GetBitmap(1,bDynamite.Glyph);
  ImageList.GetBitmap(0,bStick.Glyph);
  SwapLeftRight := true;
  DoFlow := true;
  WaterColumn := 4;
  Placing := pNone;
  InitMap;
  InitDrops;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  TimerRun.Enabled := false;
  SetLength(Map, 0);
end;


function TForm1.IsValid(nx, ny: integer): boolean;
begin
  Result := (nx>=0) and (nx<=MaxX) and (ny>=0) and (ny<=MaxY);
end;

function TForm1.IsEmpty(nx, ny: integer): boolean;
begin
  Result := (IsValid(nx,ny) and (Map[nx,ny]=mEmpty));
end;

function TForm1.IsWater(nx, ny: integer): boolean;
begin
  Result := (IsValid(nx,ny) and (Map[nx,ny]=mWater));
end;

function TForm1.IsTerrain(nx, ny: integer): boolean;
begin
  Result := (IsValid(nx,ny) and (Map[nx,ny]=mTerrain));
end;

procedure TForm1.EmptyCircle(X,Y,Radius: integer);
var sMin,sMax,sCenter: TPoint;
    ix,iy, TestX,TestY: integer;
begin
  // bepaal de pixels-vierkant waarin de cirkel precies past
  sMin.X := X - Radius;
  sMin.Y := Y - Radius;
  sMax.X := X + Radius;
  sMax.Y := Y + Radius;
  sCenter.X := sMin.X + ((sMax.X - sMin.X) div 2);
  sCenter.Y := sMin.Y + ((sMax.Y - sMin.Y) div 2);
  // maak een rond gat
  for ix:=sMin.X to sMax.X do
    for iy:=sMin.Y to sMax.Y do begin
      // binnen de cirkel??
      TestX := ix-sCenter.X;  // cirkel op de oorsprong plaatsen
      TestY := iy-sCenter.Y;
      if TestX*TestX + TestY*TestY - Radius*Radius < 0 then begin
        if not IsTerrain(ix,iy) then Continue;
        // wis de pixel
        Map[ix,iy] := mEmpty;
        BMP.Canvas.Pixels[ix,iy] := clBlack;
      end;
    end;
end;




procedure TForm1.ClearMap;
var x,y: integer;
begin
  for x:=0 to MaxX do
    for y:=0 to MaxY do
      if Map[x,y]<>mTerrain then Map[x,y] := mEmpty;
end;

procedure TForm1.InitMap;
var x,y: integer;
begin
  MaxX := BMP.Picture.Width-1;
  MaxY := BMP.Picture.Height-1;
  CenterX := (MaxX div 2);
  SetLength(Map, MaxX+1,MaxY+1);
  for x:=0 to MaxX do
    for y:=0 to MaxY do
      if BMPcopy.Canvas.Pixels[x,y]=clBlack then
        Map[x,y] := mEmpty
      else
        Map[x,y] := mTerrain;
end;

procedure TForm1.InitDrops;
var d: integer;
begin
  case rgMethod.ItemIndex of
    0: for d:=0 to MAX_DROPS-1 do begin
         drops[d].X := CenterX;
         drops[d].Y := -1;
       end;
    1: ;
  end;
  CountDrops := 0;
end;

procedure TForm1.TimerRunTimer(Sender: TObject);
begin
  AddDrop;
  case rgMethod.ItemIndex of
    0: MoveDrops;
    1: MoveDrops2;
  end;
  RenderDrops;
end;

procedure TForm1.AddDrop;
begin
  if not DoFlow then Exit;
  case rgMethod.ItemIndex of
    0: begin
      if IsEmpty(CenterX,0) then begin
        if CountDrops=MAX_DROPS then Exit;
        Inc(CountDrops);
      end;
    end;
    1: begin
      // straal 1
      if IsEmpty(CenterX,0) then begin
        if CountDrops=MAX_DROPS then Exit;
        Inc(CountDrops);
        Map[CenterX, 0] := mWater;
        BMP.Canvas.Pixels[CenterX, 0] := ColorWater;
      end;
      // straal 2
      if IsEmpty(CenterX-20,0) then begin
        if CountDrops=MAX_DROPS then Exit;
        Inc(CountDrops);
        Map[CenterX-20, 0] := mWater;
        BMP.Canvas.Pixels[CenterX-20, 0] := ColorWater;
      end;
      // straal 3
      if IsEmpty(CenterX+100,0) then begin
        if CountDrops=MAX_DROPS then Exit;
        Inc(CountDrops);
        Map[CenterX+100, 0] := mWater;
        BMP.Canvas.Pixels[CenterX+100, 0] := ColorWater;
      end;
    end;
  end;
end;

procedure TForm1.MoveDrops;
label labelDropOK,labelDropOK2;
var d: integer;
    x,y, NewX,NewY: integer;
begin
  // reset water voor nieuwe run..
  ClearMap;

  // volgende run..
  for d:=0 to CountDrops-1 do begin
    // kan de druppel recht omlaag??
    NewX := drops[d].X;
    NewY := drops[d].Y+1;
    if IsEmpty(NewX,NewY) then goto labelDropOK;
    //
    if SwapLeftRight then begin
      if SwapLeftRight then begin
        // kan 'ie naar links-links-onder??
        NewX := drops[d].X-2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar links-onder??
        NewX := drops[d].X-1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end else begin
        // kan 'ie naar links-onder??
        NewX := drops[d].X-1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar links-links-onder??
        NewX := drops[d].X-2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end;
      if SwapLeftRight then begin
        // kan 'ie naar rechts-onder??
        NewX := drops[d].X+1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar rechts-rechts-onder??
        NewX := drops[d].X+2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end else begin
        // kan 'ie naar rechts-rechts-onder??
        NewX := drops[d].X+2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar rechts-onder??
        NewX := drops[d].X+1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end;
      // kan 'ie naar links??
      NewX := drops[d].X-1;
      NewY := drops[d].Y;
      if IsEmpty(NewX,NewY) then goto labelDropOK;
      // kan 'ie naar rechts??
      NewX := drops[d].X+1;
      NewY := drops[d].Y;
      if IsEmpty(NewX,NewY) then goto labelDropOK;
    end else begin
      if SwapLeftRight then begin
        // kan 'ie naar rechts-rechts-onder??
        NewX := drops[d].X+2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar rechts-onder??
        NewX := drops[d].X+1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end else begin
        // kan 'ie naar rechts-onder??
        NewX := drops[d].X+1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar rechts-rechts-onder??
        NewX := drops[d].X+2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end;
      if SwapLeftRight then begin
        // kan 'ie naar links-links-onder??
        NewX := drops[d].X-2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar links-onder??
        NewX := drops[d].X-1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end else begin
        // kan 'ie naar links-onder??
        NewX := drops[d].X-1;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
        // kan 'ie naar links-links-onder??
        NewX := drops[d].X-2;
        NewY := drops[d].Y+1;
        if IsEmpty(NewX,NewY) then goto labelDropOK;
      end;
      // kan 'ie naar rechts??
      NewX := drops[d].X+1;
      NewY := drops[d].Y;
      if IsEmpty(NewX,NewY) then goto labelDropOK;
      // kan 'ie naar links??
      NewX := drops[d].X-1;
      NewY := drops[d].Y;
      if IsEmpty(NewX,NewY) then goto labelDropOK;
    end;
    // vast
    NewX := drops[d].X;
    NewY := drops[d].Y;

labelDropOK:
    drops[d].X := NewX;
    drops[d].Y := NewY;
    Map[NewX,NewY] := mWater;
    SwapLeftRight := not SwapLeftRight;
  end;
end;


procedure TForm1.MoveDrops2;
var d: integer;
    x,y, NewX,NewY, TestX,TestY: integer;
    leftFree,rightFree,
    leftWater, rightWater, leftWater2, rightWater2: boolean;
    Swappert, b: boolean;
//---
  procedure DoMove(x,y:integer);
  label labelDropOK2,labelDropOK3;
  var i: integer;
  begin
    // links
    TestX := x-1;
    TestY := y;
    leftFree := IsEmpty(TestX,TestY);
    leftWater := IsWater(TestX,TestY);
    // rechts
    TestX := x+1;
    TestY := y;
    rightFree := IsEmpty(TestX,TestY);
    rightWater := IsWater(TestX,TestY);


    // kan de druppel recht omlaag??
    b := false;
    NewX := x;
    NewY := y+1;
    //-- laten verdwijnen als ie uit scherm valt
    if (NewY=MaxY+1) and (cbLeaveScreen.Checked) then begin
      Map[x,y] := mEmpty;
      BMP.Canvas.Pixels[x,y] := clBlack;
      if CountDrops>0 then Dec(CountDrops);
      Exit;
    end;//--
    if IsEmpty(NewX,NewY) then begin
      b := true;
      goto labelDropOK2;
    end;
    {if (IsValid(NewX,NewY) and (Map[NewX,NewY]=mEmpty) and
       (not leftWater) and (not rightWater)) then goto labelDropOK2;}



{   // kan 'ie naar links-links-onder??
    NewX := x-2;
    NewY := y+1;
    if IsEmpty(NewX,NewY) then goto labelDropOK2;
        // kan 'ie naar rechts-rechts-onder??
    NewX := x+2;
    NewY := y+1;
    if IsEmpty(NewX,NewY) then goto labelDropOK2;}

    if Swappert then begin
      // kan 'ie naar links??
      NewX := x-1;
      NewY := y;
      if IsEmpty(NewX,NewY) then goto labelDropOK2;
      // kan 'ie naar rechts??
      NewX := x+1;
      NewY := y;
      if IsEmpty(NewX,NewY) then goto labelDropOK2;
    end else begin
      // kan 'ie naar rechts??
      NewX := x+1;
      NewY := y;
      if IsEmpty(NewX,NewY) then goto labelDropOK2;
      // kan 'ie naar links??
      NewX := x-1;
      NewY := y;
      if IsEmpty(NewX,NewY) then goto labelDropOK2;
    end;

    // vast
    Exit;


  labelDropOK2:
(*
// als ie omlaag viel, EN de grond raakt (OF water raakt),
// meteen links (of rechts) laten gaan.
if b and (not IsEmpty(NewX,NewY+1)) then begin
    // kan 'ie naar links??
    TestX := x-1;
    TestY := y+1;
    if IsEmpty(TestX,TestY) then begin NewX:=TestX; NewY:=TestY; goto labelDropOK3; end;
    // kan 'ie naar rechts??
    TestX := x+1;
    TestY := y+1;
    if IsEmpty(TestX,TestY) then begin NewX:=TestX; NewY:=TestY; goto labelDropOK3; end;
end;
*)
    // links
    TestX := NewX-1;
    TestY := NewY;
    leftFree := IsEmpty(TestX,TestY);
    leftWater := IsWater(TestX,TestY);
    // rechts
    TestX := NewX+1;
    TestY := NewY;
    rightFree := IsEmpty(TestX,TestY);
    rightWater := IsWater(TestX,TestY);

  if b then begin
    // zoek de rand van het water aan de linker-kant
    if leftWater and rightFree then begin
      TestX := NewX-1;
      TestY := NewY;
      i := 0;
      repeat
        if (not IsWater(TestX,TestY)) or (i>=tbWaterColumn.Position) then begin
          TestX := NewX+(NewX-TestX);   // (NewX-TestX) pixels aan water links
          for i:=NewX to testX do if not IsEmpty(i,TestY) then TestX:=i-1;
          for i:=TestX downto NewX do
            if IsEmpty(i,TestY) then begin
              NewX := i;
              NewY := TestY;
              goto labelDropOK3;
            end;
          Break;
        end;
        Inc(i);
        TestX := TestX-1;
      until false;
    end;
    if rightWater and leftFree then begin
      TestX := NewX+1;
      TestY := NewY;
      i := 0;
      repeat
        if (not IsWater(TestX,TestY)) or (i>=tbWaterColumn.Position) then begin
          TestX := NewX-(TestX-NewX);
          for i:=NewX downto testX do if not IsEmpty(i,TestY) then TestX:=i+1;
          for i:=TestX to NewX do
            if IsEmpty(i,TestY) then begin
              NewX := i;
              NewY := TestY;
              goto labelDropOK3;
            end;
          Break;
        end;
        Inc(i);
        TestX := TestX+1;
      until false;
    end;
  end;

    // naar links geduwd door watermassa rechts
    TestX := NewX-1;
    TestY := NewY;
    if rightWater and leftFree then begin
      NewX := TestX;
      NewY := TestY;
      goto labelDropOK3;
    end;
    // naar rechts geduwd door watermassa links
    TestX := NewX+1;
    TestY := NewY;
    if leftWater and rightFree then begin
      NewX := TestX;
      NewY := TestY;
      goto labelDropOK3;
    end;

(*
    if Swappert then begin
      // kan 'ie naar links door water??
      TestX := NewX+WaterColumn;
      TestY := NewY-1;
      rightWater := IsWater(TestX,TestY);
      TestX := NewX+WaterColumn;
      TestY := NewY;
      rightWater2 := IsWater(TestX,TestY);
      TestX := NewX-WaterColumn;
      TestY := NewY;
      leftFree := IsEmpty(TestX,TestY);
      if leftFree and (rightWater and rightWater2) then begin
        NewX := TestX;
        NewY := TestY;
//        goto labelDropOK3;
      end;
      // kan 'ie naar rechts door water??
      TestX := NewX-WaterColumn;
      TestY := NewY-1;
      leftWater := IsWater(TestX,TestY);
      TestX := NewX-WaterColumn;
      TestY := NewY;
      leftWater2 := IsWater(TestX,TestY);
      TestX := NewX+WaterColumn;
      TestY := NewY;
      rightFree := IsEmpty(TestX,TestY);
      if rightFree and (leftWater and leftWater2) then begin
        NewX := TestX;
        NewY := TestY;
//        goto labelDropOK3;
      end;
    end else begin
      // kan 'ie naar rechts door water??
      TestX := NewX-WaterColumn;
      TestY := NewY-1;
      leftWater := IsWater(TestX,TestY);
      TestX := NewX-WaterColumn;
      TestY := NewY;
      leftWater2 := IsWater(TestX,TestY);
      TestX := NewX+WaterColumn;
      TestY := NewY;
      rightFree := IsEmpty(TestX,TestY);
      if rightFree and (leftWater and leftWater2) then begin
        NewX := TestX;
        NewY := TestY;
//        goto labelDropOK3;
      end;
      // kan 'ie naar links door water??
      TestX := NewX+WaterColumn;
      TestY := NewY-1;
      rightWater := IsWater(TestX,TestY);
      TestX := NewX+WaterColumn;
      TestY := NewY;
      rightWater2 := IsWater(TestX,TestY);
      TestX := NewX-WaterColumn;
      TestY := NewY;
      leftFree := IsEmpty(TestX,TestY);
      if leftFree and (rightWater and rightWater2) then begin
        NewX := TestX;
        NewY := TestY;
//        goto labelDropOK3;
      end;
    end;
*)
  labelDropOK3:
    {if Map[NewX,NewY]<>mWater then begin}
      BMP.Canvas.Pixels[NewX,NewY] := ColorWater;
      Map[NewX,NewY] := mWater;
    {end;}
    BMP.Canvas.Pixels[x,y] := clBlack;
    Map[x,y] := mEmpty;

    // beetje laten verlopen..
{    Dec(WaterColumn);
    if WaterColumn<1 then WaterColumn:=tbWaterColumn.Position;}
  end;
//---
begin
  for x:=0 to MaxX{CenterX} do begin
//  for x:=0 to MaxX do begin
    for y:=MaxY downto 0 do begin
//    for y:=0 to MaxY do begin
      if Map[x,y] = mWater then DoMove(x,y);
      Swappert := not Swappert;
      if Map[MaxX-x,y] = mWater then DoMove(MaxX-x,y);
      Swappert := not Swappert;
    end;
  end;
end;



procedure TForm1.RenderDrops;
var d, x,y: integer;
begin
  case rgMethod.ItemIndex of
    0: begin
         BMP.Canvas.CopyRect(BMP.Canvas.ClipRect, BMPcopy.Canvas, BMPcopy.Canvas.ClipRect);
         for d:=0 to CountDrops-1 do
           BMP.Canvas.Pixels[drops[d].X, drops[d].Y] := ColorWater;
       end;
    1: {for x:=0 to MaxX do
         for y:=0 to MaxY do
           case Map[x,y] of
             mTerrain: Continue;
             mEmpty: BMP.Canvas.Pixels[x,y] := clBlack;
             mWater: BMP.Canvas.Pixels[x,y] := ColorWater;
           end};
  end;
  lDropCount.Caption := IntToStr(CountDrops);
end;

procedure TForm1.bStartClick(Sender: TObject);
begin
  if TimerRun.Enabled then begin
    bStart.Caption := 'Start';
    TimerRun.Enabled := false;
    // reset water voor nieuwe run..
    ClearMap;
  end else begin
    BMP.Canvas.CopyRect(BMP.Canvas.ClipRect, BMPcopy.Canvas, BMPcopy.Canvas.ClipRect);
    InitMap;
    InitDrops;
    bStart.Caption := 'Stop';
    TimerRun.Enabled := true;
  end;
end;

procedure TForm1.bFlowClick(Sender: TObject);
begin
  DoFlow := not DoFlow;
end;

procedure TForm1.BMPMouseMove(Sender: TObject; Shift: TShiftState; X,  Y: Integer);
begin
  if Placing <> pNone then Exit;
  // wis het terrein onder de muiscursor
  if not (ssLeft in Shift) then Exit;
  {Map[X,Y] := mEmpty;
  BMP.Canvas.Pixels[X,Y] := clBlack;}
  EmptyCircle(X,Y, tbEraseRadius.Position);
end;

procedure TForm1.BMPMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var imgCenterX,imgCenterY, ix,iy: integer;
begin
  imgCenterX := ImageList.Width div 2;
  imgCenterY := ImageList.Height div 2;

  if (ssRight in Shift) then begin
    // annuleer plaatsen van dynamite/stick
    Placing := pNone;
  end;
  if (ssLeft in Shift) then begin
    // plaats een dynamite/stick
    case Placing of
      pDynamite: begin
        if not TimerDynamite.Enabled then begin
          DynamitePos := Point(X,Y);
          TimerDynamite.Enabled := true;
          // teken een dynamite
          ImageList.Draw(BMP.Canvas, X-imgCenterX,Y-imgCenterY, 1);
        end;
      end;
      pStick: begin
        StickPos := Point(X,Y);
        // teken een stick
        ImageList.Draw(BMP.Canvas, X-imgCenterX,Y-imgCenterY, 0);
        // markeer stick-pixels als zijnde terrein
        for iy:=0 to imgStick.Height-1 do begin
          for ix:=0 to imgStick.Width-1 do begin
            if imgStick.Canvas.Pixels[ix,iy] = clBlack then Continue;
            if IsValid(StickPos.X-imgCenterX+ix,StickPos.Y-imgCenterY+iy) then
              Map[StickPos.X-imgCenterX+ix,StickPos.Y-imgCenterY+iy] := mTerrain;
          end;
        end;
      end;
    end;
  end;
end;

procedure TForm1.BMPMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  Placing := pNone;
end;


procedure TForm1.bDynamiteClick(Sender: TObject);
begin
  //Form1.Cursor := crHourGlass;
  Placing := pDynamite;
end;

procedure TForm1.bStickClick(Sender: TObject);
begin
  //
  Placing := pStick;
end;

procedure TForm1.TimerDynamiteTimer(Sender: TObject);
var sMin,sMax,sCenter: TPoint;
    x,y, TestX,TestY: integer;
begin
  // laat dynamite ontploffen
  TimerDynamite.Enabled := false;
  EmptyCircle(DynamitePos.X,DynamitePos.Y, DYNAMITE_RADIUS);
end;

end.

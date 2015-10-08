unit x4;
(* *
  * name : x4
  * relase: 30 sep 2015 .
  * requerment: Delphi XE2 .
  * update : 9 Oct 2015 .
  * website : www.4xmen.ir
  * vertion : 1.1
  * *)

interface

uses System.SysUtils, System.Classes, Vcl.Forms, IdCoder, IdCoderMIME, IdGlobal,
  Data.DB, Data.Win.ADODB, Data.DBXMSSQL, Data.SqlExpr, Winapi.msxml,
  Winapi.Windows, System.Win.Registry;

type

  TAssoc = record
    Key: ShortString;
    Value: Variant;
    Next: Pointer;
    Child: Pointer;
  end;

  PAssoc = ^TAssoc;

  TAssocArray = class
  private
  var
    Head: TAssoc;
    xml: IXMLDOMDocument;
    function FindKeyOffset(cHead: PAssoc; Key: ShortString): PAssoc;
  public
    constructor Create();
    procedure vSet(Key: ShortString; InVar: Variant);
    function vGet(Key: ShortString): Variant;
    procedure vDel(Key: ShortString);
    procedure vSetChild(parent, Key: string; Value: Variant);
    function toXML(cHead: PAssoc): WideString;
    procedure fromXML(xFile: WideString);

  published

  end;

function GetAppDir(): string;
function GetOSType(): string; // Requires XE2 or newer.
function GetOSVerstion(): string; // Requires XE2 or newer.
function GetOSName(): string; // Requires XE2 or newer.
function GetOSDetail(): string; // Requires XE2 or newer.
procedure FatalError(Title, Text: string; Terminate: Boolean);

function Explode(Delimiter: Char; Str: string): TStrings;
// Requires D2006 or newer.
function Implode(Str: TStrings; Delimiter: Char): string;

function Base64Encode(Input: WideString): string;
function Base64Decode(Input: WideString): string;

function DrawXMLFromADO(qry: TADOQuery): string;
function DrawXMLFromDBX(qry: TSQLQuery): string;

function SetRegValue(Key, Value: string): Boolean;
function GetRegValue(Key: string): string;
function IsAppStartUp(app: string): Boolean;
function SetAppStartUp(app: string): Boolean;
function UnsetAppStartUP(app: string): Boolean;

implementation

const
  _KEY_ = 'YourAppname';
  APP_KEY = 'SOFTWARE\' + _KEY_;
  START_KEY = 'Software\Microsoft\Windows\CurrentVersion\Run';

  (* *
    *  get instance from this class
    * *)
constructor TAssocArray.Create;
begin
  Head.Key := '';
  Head.Value := '';
  Head.Next := nil;
  Head.Child := nil;
end;

(* *
  *  draw this system to xml
  * *)
function TAssocArray.toXML(cHead: PAssoc): WideString;
var
  p, q: PAssoc;
begin
  Result := '';
  // if the head add root
  if cHead = nil then
  begin
    cHead := Head.Next;
    Result := '<root>';
  end
  else
  begin
    cHead := cHead^.Child;
  end;
  p := cHead;
  q := nil;
  while p <> nil do
  begin
    q := p;
    // add item
    Result := Result + '<item>' + #13#10;
    Result := Result + '<key>' + q^.Key + '</key>' + #13#10;
    Result := Result + '<value>' + q^.Value + '</value>' + #13#10;
    // if has chaild .
    if q^.Child <> nil then
    begin
      Result := Result + '<subitems>' + #13#10;
      Result := Result + toXML(q);
      Result := Result + '</subitems>' + #13#10;
    end;
    Result := Result + '</item>' + #13#10;
    p := p^.Next;
  end;
  // ikf the head close added root
  if cHead = Head.Next then
  begin
    Result := Result + '</root>';
  end;
end;

(* *
  *  find offest keys
  * *)

function TAssocArray.FindKeyOffset(cHead: PAssoc; Key: ShortString): PAssoc;
var
  p, q: PAssoc;
begin
  p := cHead;
  q := nil;
  // each to end .
  while p <> nil do
  begin
    q := p;
    if q^.Key = Key then
    begin
      Result := q;
      Exit;
    end;
    p := p^.Next;
  end;
  Result := nil;
end;

(* *
  *  get key value
  * *)
function TAssocArray.vGet(Key: ShortString): Variant;
var
  p, q: PAssoc;
begin
  p := @Head;
  q := nil;
  while p <> nil do
  begin
    q := p;
    // if find key .
    if q^.Key = Key then
    begin
      Result := q^.Value;
      Exit;
    end;
    p := p^.Next;
  end;
  Result := False;
end;

(* *
  *  set an key value
  * *)
procedure TAssocArray.vSet(Key: ShortString; InVar: Variant);
var
  p, q, nw: PAssoc;
begin
  p := @Head;
  q := nil;
  while p <> nil do
  begin
    q := p;
    // if find key .
    if q^.Key = Key then
    begin
      q^.Value := InVar;
      Exit;
    end;
    p := p^.Next;
  end;
  // else append an value in this
  New(nw);
  nw^.Value := InVar;
  nw^.Key := Key;
  nw^.Next := nil;
  nw^.Child := nil;
  q^.Next := nw;
end;

(* *
  *  delete value by key
  * *)
procedure TAssocArray.vDel(Key: ShortString);
var
  p, q, nx: PAssoc;
begin
  p := @Head;
  q := nil;
  while p <> nil do
  begin
    q := p;
    p := p^.Next;

    // if set key delete from this
    if p^.Key = Key then
    begin
      q^.Next := p^.Next;
      FreeMemory(p);
      Exit;
    end;
  end;

end;

(* *
  *  set an child in the system .
  * *)
procedure TAssocArray.vSetChild(parent: string; Key: string; Value: Variant);
var
  items: TStrings;
  toAdd, lastHead, nw, p: PAssoc;
  I: Integer;
begin
  items := Explode(',', parent);
  // this 1D array .
  if items.Count = 1 then
  begin
    toAdd := FindKeyOffset(@Head, items.Strings[0]);
    if toAdd = nil then
    begin
      Exit;

    end;
  end
  else
  begin
    // else more than 1D array 2D,3D,4D ;
    lastHead := @Head;
    // each keys tuntil key .
    for I := 0 to items.Count - 1 do
    begin
      toAdd := FindKeyOffset(lastHead, items.Strings[I]);
      if toAdd = nil then
      begin
        Exit;
      end
      else
      begin
        lastHead := toAdd.Child;
      end;
    end;
  end;
  // alloc sapcce to add child.
  New(nw);
  nw^.Child := nil;
  nw^.Next := nil;
  nw^.Key := Key;
  nw^.Value := Value;
  // if has not child be fore than
  if toAdd^.Child = nil then
  begin
    toAdd^.Child := nw;
  end
  else
  begin
    // if has child before than append to array.
    p := toAdd.Child;
    toAdd := nil;
    while p <> nil do
    begin
      toAdd := p;
      p := p^.Next;
    end;
    toAdd.Next := nw;
  end;

end;

procedure TAssocArray.fromXML(xFile: WideString);
var
  Node, lNode, SubNode: IXMLDOMNode;
  I: Integer;
begin
  xml := CoDOMDocument.Create;
  xml.loadXML(xFile);
  // xml.
  Node := xml.firstChild;
  lNode := Node.firstChild;
  for I := 0 to Node.childNodes.length - 1 do
  begin
    vSet(lNode.firstChild.Text, lNode.firstChild.nextSibling.Text);
    lNode := lNode.nextSibling;
  end;

end;

(* *
  *  Get application ccurrent directory .
  * *)
function GetAppDir(): string;
begin
  Result := ExtractFilePath(Application.ExeName);
end;

(* *
  *  get os type (win|linux|mac|etc)
  * *)
function GetOSType(): string;
begin
  case TOSVersion.Platform of
    pfMacOS:
      begin
        Result := 'MacOSX';
        Exit;
      end;
    pfLinux:
      begin
        Result := 'Linux';
        Exit;
      end;
    pfAndroid:
      begin
        Result := 'pfAndroid';
        Exit;
      end;
    pfWinRT:
      begin
        Result := 'WinRT';
        Exit;
      end;
    pfiOS:
      begin
        Result := 'iOS';
        Exit;
      end;
    pfWindows:
      begin
        Result := 'Windows';
        Exit;
      end;
  end;
end;

(* *
  *  os vertion
  * *)
function GetOSVerstion(): string;
begin
  Result := IntToStr(TOSVersion.Major) + '.' + IntToStr(TOSVersion.Minor);
end;

(* *
  *  what is os vertion
  * *)
function GetOSName(): string;
begin
  Result := TOSVersion.Name;
end;

(* *
  *  os full detail
  * *)
function GetOSDetail(): string;
begin
  Result := TOSVersion.ToString;
end;

(* *
  * base64 encoode
  * @param  widestring Input string to endode
  * *)
function Base64Encode(Input: WideString): string;

begin
  Result := TIdEncoderMIME.EncodeString(Input, IndyTextEncoding_UTF8);
end;

(* *
  * base64 decode
  * @param  widestring Input string to decode
  * *)
function Base64Decode(Input: WideString): string;

begin
  Result := TIdDecoderMIME.DecodeString(Input, IndyTextEncoding_UTF8);
end;

(* *
  *   explode string
  * *)

function Explode(Delimiter: Char; Str: string): TStrings;

begin
  Result := TStringList.Create;
  Result.Delimiter := Delimiter;
  Result.StrictDelimiter := True; // Requires D2006 or newer.
  Result.DelimitedText := Str;
end;

(* *
  *   implode strings
  * *)

function Implode(Str: TStrings; Delimiter: Char): string;
var
  I: Integer;
begin

  Result := '';
  for I := 0 to Str.Count - 1 do
  begin
    Result := Result + Str.Strings[I] + Delimiter;
  end;
  Delete(Result, length(Result), 1);
end;

(* *
  *   Addoquery to xml
  * *)

function DrawXMLFromADO(qry: TADOQuery): string;
var
  lst: TStringList;
  I: Integer;
  j: Integer;
begin
  lst := TStringList.Create;
  qry.GetFieldNames(lst);
  Result := '<root>' + #13#10;
  Result := Result + '    <cols>' + #13#10;
  for I := 0 to lst.Count - 1 do
  begin
    Result := Result + '        <col>' + lst.Strings[I] + '</col>' + #13#10;
  end;
  Result := Result + '    </cols>' + #13#10;

  Result := Result + '    <records>' + #13#10;
  for I := 0 to qry.RecordCount - 1 do
  begin
    Result := Result + '        <record>' + #13#10;
    for j := 0 to lst.Count - 1 do
    begin
      Result := Result + '            <field>';
      Result := Result + Trim(qry.Fields[j].AsString);
      Result := Result + '</field>' + #13#10;
    end;
    Result := Result + '        </record>' + #13#10;
    qry.Next;
  end;
  Result := Result + '    </records>' + #13#10;
  Result := Result + '</root>' + #13#10;
end;

(* *
  *   TSQLQuery to xml
  * *)

function DrawXMLFromDBX(qry: TSQLQuery): string;

var
  lst: TStringList;
  I: Integer;
  j: Integer;

begin
  lst := TStringList.Create;
  qry.GetFieldNames(lst);
  Result := '<root>' + #13#10;
  Result := Result + '    <cols>' + #13#10;
  for I := 0 to lst.Count - 1 do
  begin
    Result := Result + '        <col>' + lst.Strings[I] + '</col>' + #13#10;
  end;
  Result := Result + '    </cols>' + #13#10;

  Result := Result + '    <records>' + #13#10;
  for I := 0 to qry.RecordCount - 1 do
  begin
    Result := Result + '        <record>' + #13#10;
    for j := 0 to lst.Count - 1 do
    begin
      Result := Result + '            <field>';
      Result := Result + Trim(qry.Fields[j].AsString);
      Result := Result + '</field>' + #13#10;
    end;
    Result := Result + '        </record>' + #13#10;
    qry.Next;
  end;
  Result := Result + '    </records>' + #13#10;
  Result := Result + '</root>' + #13#10;
end;

(* *
  *  show fatal error in  application
  * *)

procedure FatalError(Title, Text: string; Terminate: Boolean);
begin
  MessageBoxW(0, PWideChar(Text), PWideChar(Title), 16);
  if (Terminate) then
    Application.Terminate;
end;


(* *
  *  set registry key in app
  * *)

function SetRegValue(Key, Value: string): Boolean;
var
  rg: TRegistry;
begin
  rg := TRegistry.Create;
  rg.RootKey := HKEY_CURRENT_USER;
  if rg.OpenKey(APP_KEY, True) then
  begin
    rg.WriteString(Key, Value);
    Result := True;
  end
  else
  begin
    Result := False;
  end;
  rg.Free;
end;


(* *
  *  get resgitery keu in app
  * *)

function GetRegValue(Key: string): string;
var
  rg: TRegistry;
begin
  rg := TRegistry.Create;
  rg.RootKey := HKEY_CURRENT_USER;
  if rg.OpenKey(APP_KEY, False) then
  begin
    if rg.ValueExists(Key) then
    begin
      Result := rg.ReadString(Key);
    end
    else
    begin
      Result := 'null';
    end;
  end
  else
  begin
    Result := 'null';
  end;
  rg.Free;
end;

(* *
  *  is application start up function
  * *)

function IsAppStartUp(app: string): Boolean;
var
  rg: TRegistry;
begin
  rg := TRegistry.Create;
  rg.RootKey := HKEY_CURRENT_USER;
  Result := False;
  if rg.OpenKey(START_KEY, False) then
  begin
    if ((rg.ValueExists(_KEY_)) and (rg.ReadString(_KEY_) = app)) then
    begin
      Result := True;
    end;
  end;
  rg.Free;
end;

(* *
  *  set application start up
  * *)


function SetAppStartUp(app: string): Boolean;
var
  rg: TRegistry;
begin
  rg := TRegistry.Create;
  rg.RootKey := HKEY_CURRENT_USER;
  Result := False;
  if rg.OpenKey(START_KEY, True) then
  begin
    rg.WriteString(_KEY_, app);
    Result := True;
  end;
  rg.Free;
end;


(* *
  *  unset Application startup
  * *)

function UnsetAppStartUP(app: string): Boolean;
var
  rg: TRegistry;
begin
  rg := TRegistry.Create;
  rg.RootKey := HKEY_CURRENT_USER;
  Result := False;
  if rg.OpenKey(START_KEY, False) then
  begin
    if rg.ValueExists(_KEY_) and (rg.ReadString(_KEY_) = app) then
    begin
      rg.DeleteValue(_KEY_);
      Result := True;
    end;
  end;
  rg.Free;
end;


end.

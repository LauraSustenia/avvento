$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$references=@([AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES').Split([IO.Path]::PathSeparator))
$references+=@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { -not $_.IsDynamic -and $_.Location } | ForEach-Object Location)
Add-Type -ReferencedAssemblies ($references | Select-Object -Unique) -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
public static class HeaderPaintedJoint {
 const int W=2172,Head=706,Band=724;
 static Bitmap Load(string file,int height){using(var image=new Bitmap(file)){var b=new Bitmap(W,height,PixelFormat.Format32bppArgb);using(var g=Graphics.FromImage(b)){g.CompositingMode=CompositingMode.SourceCopy;g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(image,0,0,W,height);}return b;}}
 static Color Mix(Color a,Color b,double t){double aa=a.A*(1-t),ba=b.A*t,s=aa+ba;if(s<.001)return Color.FromArgb(0,0,0,0);return Color.FromArgb((int)Math.Round(s),(int)Math.Round((a.R*aa+b.R*ba)/s),(int)Math.Round((a.G*aa+b.G*ba)/s),(int)Math.Round((a.B*aa+b.B*ba)/s));}
 public static void Install(string root){
  string source=Path.Combine(root,"scripts","frame-source"),output=Path.Combine(root,"images","cornice-png");
  using(var draft=Load(Path.Combine(source,"header-first-joint-draft.png"),Head+Band))using(var painted=Load(Path.Combine(source,"header-first-joint-painted.png"),Head+Band))using(var composite=(Bitmap)draft.Clone()){
   for(int y=550;y<880;y++){
    double opacity=Math.Min(1,Math.Min((y-550)/30.0,(880-y)/30.0));
    for(int x=0;x<W;x++)if((x>=60&&x<=180)||(x>=W-181&&x<=W-61)){
     var original=draft.GetPixel(x,y);var repair=painted.GetPixel(x,y);
     // Mantiene il ritaglio trasparente originale, escludendo gli aloni della ridipintura.
     repair=Color.FromArgb(Math.Min(original.A,repair.A),repair.R,repair.G,repair.B);
     composite.SetPixel(x,y,Mix(original,repair,opacity));
    }
   }
   using(var header=composite.Clone(new Rectangle(0,0,W,Head),PixelFormat.Format32bppArgb))header.Save(Path.Combine(output,"testa.png"),ImageFormat.Png);
   for(int i=1;i<=6;i++)using(var band=Load(Path.Combine(output,"fascia-"+i+".png"),Band)){
    for(int y=0;y<174;y++)for(int x=0;x<W;x++)if((x>=60&&x<=180)||(x>=W-181&&x<=W-61))band.SetPixel(x,y,composite.GetPixel(x,Head+y));
    band.Save(Path.Combine(output,"fascia-inizio-"+i+".png"),ImageFormat.Png);
   }
  }
  Console.WriteLine("Testata e sei prime fasce ricavate dalla stessa giunzione dipinta.");
 }
}
'@
[HeaderPaintedJoint]::Install((Split-Path $PSScriptRoot -Parent))

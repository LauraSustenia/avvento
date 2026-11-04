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
public static class SharedPaintedFrame {
 const int W=2172,H=724,Cap=120;
 static Bitmap Load(string file){using(var source=new Bitmap(file)){var b=new Bitmap(W,H,PixelFormat.Format32bppArgb);using(var g=Graphics.FromImage(b)){g.CompositingMode=CompositingMode.SourceCopy;g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(source,0,0,W,H);}return b;}}
 static Color Mix(Color a,Color b,double t){double aa=a.A*(1-t),ba=b.A*t,s=aa+ba;if(s<.001)return Color.FromArgb(0,0,0,0);return Color.FromArgb((int)Math.Round(s),(int)Math.Round((a.R*aa+b.R*ba)/s),(int)Math.Round((a.G*aa+b.G*ba)/s),(int)Math.Round((a.B*aa+b.B*ba)/s));}
 static void CopyRows(Bitmap target,Bitmap source,int sourceY,int targetY,int count){for(int y=0;y<count;y++)for(int x=0;x<W;x++)target.SetPixel(x,targetY+y,source.GetPixel(x,sourceY+y));}
 static void Decor(Bitmap b,string file,int x,int y,int size,float angle){using(var leaf=new Bitmap(file))using(var g=Graphics.FromImage(b)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.SmoothingMode=SmoothingMode.HighQuality;g.TranslateTransform(x,y);g.RotateTransform(angle);g.DrawImage(leaf,-size/2,-size/2,size,size);}}
 static void Check(Bitmap b,Bitmap master,bool top,bool bottom){for(int x=0;x<W;x++){if(top&&b.GetPixel(x,0).ToArgb()!=master.GetPixel(x,0).ToArgb())throw new Exception("Bordo superiore");if(bottom&&b.GetPixel(x,b.Height-1).ToArgb()!=master.GetPixel(x,0).ToArgb())throw new Exception("Bordo inferiore");}}
 public static void Build(string root){
  string images=Path.Combine(root,"images"),source=Path.Combine(root,"scripts","frame-source"),output=Path.Combine(images,"cornice-png");Directory.CreateDirectory(output);
  using(var raw=Load(Path.Combine(source,"fascia-3.png")))using(var master=Load(Path.Combine(source,"shared-master.png"))){
   // Caps are actual unwarped painted pixels from one common reference, not synthesized strokes.
   CopyRows(master,raw,0,0,Cap);CopyRows(master,raw,H-Cap,H-Cap,Cap);
   // Il lato sinistro ha terminali compatibili; lo stesso disegno specchiato garantisce quelli destri.
   for(int y=0;y<H;y++)for(int x=0;x<W/2;x++)master.SetPixel(W-1-x,y,master.GetPixel(x,y));
   // The reference already has nearly coincident natural endpoints; only the last few rows are made periodic.
   for(int x=0;x<W;x++)master.SetPixel(x,H-1,master.GetPixel(x,0));
   master.Save(Path.Combine(output,"base-comune.png"),ImageFormat.Png);
   string[] files={"foglia-farnia.png","foglia-edera.png","foglia-acero.png","foglia-pioppo.png","fiocco-cornice.png"};
   // file, x, y, size, angle: each section has a different irregular composition.
   int[][][] variants={
    new[]{new[]{0,195,300,58,-35},new[]{4,2141,190,52,10}},
    new[]{new[]{1,32,210,55,-48},new[]{4,1982,487,48,-8},new[]{3,2130,390,40,34}},
    new[]{new[]{4,30,465,47,12},new[]{1,2000,290,57,30},new[]{0,102,360,38,-40}},
    new[]{new[]{2,194,215,53,26},new[]{4,2140,510,51,10}},
    new[]{new[]{1,1980,480,57,-22},new[]{4,34,250,46,0},new[]{3,28,530,39,-55}},
    new[]{new[]{4,110,235,49,-10},new[]{0,2136,490,55,40},new[]{1,1967,300,40,-25}}
   };
   for(int i=0;i<6;i++)using(var band=(Bitmap)master.Clone()){
    foreach(var d in variants[i])Decor(band,Path.Combine(images,files[d[0]]),d[1],d[2],d[3],d[4]);
    Check(band,master,true,true);band.Save(Path.Combine(output,"fascia-"+(i+1)+".png"),ImageFormat.Png);
   }
   using(var original=Load(Path.Combine(images,"testa.png")))using(var draft=(Bitmap)original.Clone()){
    using(var g=Graphics.FromImage(draft)){g.DrawImage(master,new Rectangle(0,H-160,W,160),new Rectangle(0,H-160,W,160),GraphicsUnit.Pixel);}
    draft.Save(Path.Combine(source,"draft-head-final.png"),ImageFormat.Png);
    string repaired=Path.Combine(source,"head-final-painted.png");
    using(var result=File.Exists(repaired)?Load(repaired):(Bitmap)draft.Clone()){
     // Protegge il logo originale, senza tagli orizzontali nelle illustrazioni laterali.
     for(int y=310;y<535;y++)for(int x=400;x<1770;x++)result.SetPixel(x,y,original.GetPixel(x,y));
     // L'immagine ritoccata può avere margine trasparente sotto i tronchi: lo elimina senza stirare il disegno.
     int last=H-1;
     for(int y=H-1;y>H-110;y--){bool full=true;foreach(int center in new[]{89,149,2023,2083}){int count=0;for(int x=center-18;x<=center+18;x++)if(result.GetPixel(x,y).A>200)count++;if(count<10)full=false;}if(full){last=y;break;}}
     using(var cropped=result.Clone(new Rectangle(0,0,W,last+1),PixelFormat.Format32bppArgb)){
      CopyRows(cropped,master,0,cropped.Height-1,1);
      Check(cropped,master,false,true);cropped.Save(Path.Combine(output,"testa.png"),ImageFormat.Png);
      Console.WriteLine("Altezza testa raccordata: "+cropped.Height);
     }
    }
   }
   using(var original=Load(Path.Combine(images,"coda.png")))using(var result=new Bitmap(W,H,PixelFormat.Format32bppArgb)){
    using(var g=Graphics.FromImage(result)){
     g.DrawImage(master,new Rectangle(0,0,W,520),new Rectangle(0,0,W,520),GraphicsUnit.Pixel);
     // Il paesaggio originale copre naturalmente le estremità dei rami: nessuna fascia tagliata.
     g.DrawImage(original,0,0,W,H);
    }
    CopyRows(result,master,0,0,1);
    Check(result,master,true,false);result.Save(Path.Combine(output,"coda.png"),ImageFormat.Png);
   }
   Console.WriteLine("Otto PNG composte. Nessuna deformazione geometrica dei rami. Raccordi comuni verificati.");
  }
 }
}
'@
[SharedPaintedFrame]::Build((Split-Path $PSScriptRoot -Parent))
if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'frame-source/header-first-joint-painted.png')) { & (Join-Path $PSScriptRoot 'install-header-joint.ps1') }

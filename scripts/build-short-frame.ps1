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
public static class ShortPaintedFrame {
 const int W=2172,H=360,S=240,Blend=80,Head=706;
 struct Run { public int L,R; public double Center {get{return (L+R)/2.0;}} public double Width {get{return R-L+1;}} }
 static double Ease(double t){return t*t*t*(10+t*(-15+6*t));}
 static bool SamePixel(Color a,Color b){return a.A==0&&b.A==0||a.ToArgb()==b.ToArgb();}
 static Color Mix(Color a,Color b,double t){double aa=a.A*(1-t),ba=b.A*t,s=aa+ba;if(s<.001)return Color.Transparent;return Color.FromArgb((int)Math.Round(s),(int)Math.Round((a.R*aa+b.R*ba)/s),(int)Math.Round((a.G*aa+b.G*ba)/s),(int)Math.Round((a.B*aa+b.B*ba)/s));}
 static Run[] Runs(Bitmap b,int y){
  Run[] found=new Run[32];int count=0,start=-1;
  for(int x=0;x<=b.Width;x++){
   bool on=x<b.Width&&b.GetPixel(x,y).A>=100;
   if(on&&start<0)start=x;
   if(!on&&start>=0){if(x-start>=3&&count<found.Length)found[count++]=new Run{L=start,R=x-1};start=-1;}
  }
  if(count<2)throw new Exception("Servono due rami separati nella zona di raccordo, riga "+y+", trovati "+count);
  for(int i=0;i<count;i++)for(int j=i+1;j<count;j++)if(found[j].Width>found[i].Width){var swap=found[i];found[i]=found[j];found[j]=swap;}
  Run first=found[0],second=found[1];return first.Center<second.Center?new[]{first,second}:new[]{second,first};
 }
 static Color Sample(Bitmap b,double x,int y){if(x<0||x>=b.Width-1)return Color.Transparent;int left=(int)Math.Floor(x);return Mix(b.GetPixel(left,y),b.GetPixel(left+1,y),x-left);}
 static double Median(double[] data,int count){Array.Sort(data,0,count);return data[count/2];}
 static double[] Profile(Bitmap image,int y){
  double[][] values={new double[15],new double[15],new double[15],new double[15]};double[] weights=new double[15];int count=0;
  for(int row=Math.Max(0,y-7);row<=Math.Min(image.Height-1,y+7);row++){
   Run[] runs;try{runs=Runs(image,row);}catch{continue;}
   values[0][count]=runs[0].Center;values[1][count]=runs[0].Width;values[2][count]=runs[1].Center;values[3][count]=runs[1].Width;weights[count]=Math.Exp(-(row-y)*(row-y)/32.0);count++;
  }
  if(count==0)throw new Exception("Profilo dei rami non leggibile");
  double[] result=new double[4];
  for(int field=0;field<4;field++){
   var sorted=(double[])values[field].Clone();double median=Median(sorted,count),sum=0,total=0;
   for(int i=0;i<count;i++)if(Math.Abs(values[field][i]-median)<((field%2)==0?8:6)){sum+=values[field][i]*weights[i];total+=weights[i];}
   result[field]=total>0?sum/total:median;
  }
  return result;
 }
 static double[] Anchors(double[] p){return new[]{0.0,p[0]-p[1]/2,p[0]+p[1]/2,p[2]-p[3]/2,p[2]+p[3]/2,S-1.0};}
 static double Warp(double x,double[] target,double[] source){
  for(int i=0;i<target.Length-1;i++)if(x<=target[i+1]){double t=(x-target[i])/(target[i+1]-target[i]);return source[i]+t*(source[i+1]-source[i]);}
  return source[source.Length-1];
 }
 // Warps and blends the whole raster row, including every offshoot and its antialiased edge.
 // Cropping each twig to its detected trunk width produced the horizontal slices in the previous version.
 static void JoinRow(Bitmap target,int targetY,Bitmap a,int ay,Bitmap b,int by,double t){
  if(t<=0||t>=1){var source=t<=0?a:b;int row=t<=0?ay:by;for(int x=0;x<target.Width;x++)target.SetPixel(x,targetY,source.GetPixel(x,row));return;}
  var pa=Profile(a,ay);var pb=Profile(b,by);var combined=new double[4];
  for(int i=0;i<4;i++)combined[i]=pa[i]*(1-t)+pb[i]*t;
  var aa=Anchors(pa);var ab=Anchors(pb);var at=Anchors(combined);
  for(int x=0;x<target.Width;x++){
   var ca=Sample(a,Warp(x,at,aa),ay);var cb=Sample(b,Warp(x,at,ab),by);
   target.SetPixel(x,targetY,Mix(ca,cb,t));
  }
 }
 static Bitmap Side(Bitmap image,bool right){var result=new Bitmap(S,image.Height,PixelFormat.Format32bppArgb);using(var g=Graphics.FromImage(result)){g.CompositingMode=CompositingMode.SourceCopy;g.DrawImage(image,new Rectangle(0,0,S,image.Height),new Rectangle(right?W-S:0,0,S,image.Height),GraphicsUnit.Pixel);}if(right)result.RotateFlip(RotateFlipType.RotateNoneFlipX);return result;}
 static void InstallSide(Bitmap target,Bitmap side,bool right,int y0,int count){for(int y=y0;y<y0+count;y++)for(int x=0;x<S;x++)target.SetPixel(right?W-1-x:x,y,side.GetPixel(x,y));}
 static void Decor(Bitmap b,string file,int x,int y,int size,float angle){using(var leaf=new Bitmap(file))using(var g=Graphics.FromImage(b)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.TranslateTransform(x,y);g.RotateTransform(angle);g.DrawImage(leaf,-size/2,-size/2,size,size);}}
 static Bitmap Prepare(string file,int paintedHeight,int cropY){
  using(var generated=new Bitmap(file)){
   var raw=new Bitmap(S,H,PixelFormat.Format32bppArgb);
   // Uniform reduction followed by a crop; original width-to-height proportions are preserved.
   int width=(int)Math.Round(generated.Width*(double)paintedHeight/generated.Height);
   using(var g=Graphics.FromImage(raw)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(generated,0,-cropY,width,paintedHeight);}
   return raw;
  }
 }
 static Bitmap Connector(string file){
  using(var generated=new Bitmap(file)){
   var result=new Bitmap(S,160,PixelFormat.Format32bppArgb);int width=(int)Math.Round(generated.Width*500.0/generated.Height);
   // A bare, nearly vertical stretch of the actual painted twigs: no side shoots are cut at the joins.
   using(var g=Graphics.FromImage(result)){g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(generated,0,-340,width,500);}
   return result;
  }
 }
 static Bitmap Tile(Bitmap raw,Bitmap connector){
  var tile=(Bitmap)raw.Clone();const int blend=64;
  for(int y=0;y<blend;y++){
   for(int x=0;x<S;x++){tile.SetPixel(x,y,Color.Transparent);tile.SetPixel(x,H-blend+y,Color.Transparent);}
   JoinRow(tile,y,connector,Blend+y,raw,y,Ease(y/(double)(blend-1)));
   JoinRow(tile,H-blend+y,raw,H-blend+y,connector,Blend-blend+y,Ease(y/(double)(blend-1)));
  }
  return tile;
 }
 public static void Build(string root){
  string source=Path.Combine(root,"scripts","frame-source"),output=Path.Combine(root,"images","cornice-corta"),images=Path.Combine(root,"images");Directory.CreateDirectory(output);
  // All variants use native crops of the smoothly painted source; the zig-zag illustrations are excluded.
  using(var raw=Prepare(Path.Combine(source,"short","twigs.png"),500,70))using(var common=Connector(Path.Combine(source,"short","twigs.png")))using(var other1=Prepare(Path.Combine(source,"short","twigs.png"),500,15))using(var other2=Prepare(Path.Combine(source,"short","twigs.png"),500,125)){
   raw.Save(Path.Combine(output,"rami-sorgente.png"),ImageFormat.Png);
   using(var tile=Tile(raw,common))using(var tile1=Tile(other1,common))using(var tile2=Tile(other2,common)){
    Bitmap[] tiles={tile,tile1,tile2};int[] left={0,1,2,0,2,1},rightSide={2,0,1,1,0,2};
    using(var master=new Bitmap(W,H,PixelFormat.Format32bppArgb)){
     InstallSide(master,tile,false,0,H);InstallSide(master,tile,true,0,H);
     master.Save(Path.Combine(output,"base-comune.png"),ImageFormat.Png);
     string[] files={"foglia-farnia.png","foglia-edera.png","foglia-acero.png","foglia-pioppo.png","fiocco-cornice.png"};
     int[][][] variants={
      new[]{new[]{0,193,150,58,-35},new[]{4,2141,85,52,10}},
      new[]{new[]{3,2130,210,40,34}},
      new[]{new[]{4,30,255,47,12},new[]{1,2000,145,57,30}},
      new[]{new[]{2,194,105,53,26}},
      new[]{new[]{1,1980,265,57,-22},new[]{4,34,110,46,0}},
      new[]{new[]{4,110,120,49,-10},new[]{0,2136,265,55,40}}
     };
     for(int i=0;i<6;i++)using(var band=(Bitmap)master.Clone()){
      InstallSide(band,tiles[left[i]],false,0,H);InstallSide(band,tiles[rightSide[i]],true,0,H);
      foreach(var d in variants[i])Decor(band,Path.Combine(images,files[d[0]]),d[1],d[2],d[3],d[4]);
      band.Save(Path.Combine(output,"fascia-"+(i+1)+".png"),ImageFormat.Png);
     }
    }
    using(var draft=new Bitmap(Path.Combine(source,"header-first-joint-draft.png")))using(var head=draft.Clone(new Rectangle(0,0,W,Head),PixelFormat.Format32bppArgb)){
     foreach(bool right in new[]{false,true})using(var old=Side(head,right))using(var joined=(Bitmap)old.Clone()){
      for(int y=0;y<Blend;y++){
       int target=Head-Blend+y;for(int x=0;x<S;x++)joined.SetPixel(x,target,Color.Transparent);
       JoinRow(joined,target,old,target,common,y,Ease(y/(double)(Blend-1)));
      }
      InstallSide(head,joined,right,Head-Blend,Blend);
     }
     head.Save(Path.Combine(output,"testa.png"),ImageFormat.Png);
    }
    using(var original=new Bitmap(Path.Combine(images,"coda.png")))using(var tail=new Bitmap(W,original.Height,PixelFormat.Format32bppArgb)){
     // The new continuous raster branches sit behind the untouched original pond illustration.
     for(int y=0;y<540;y++)for(int x=0;x<S;x++){
      Color pixel=tile.GetPixel(x,y%H);
      if(y>420)pixel=Color.FromArgb((int)Math.Round(pixel.A*(540-y)/120.0),pixel.R,pixel.G,pixel.B);
      tail.SetPixel(x,y,pixel);tail.SetPixel(W-1-x,y,pixel);
     }
     using(var g=Graphics.FromImage(tail)){g.DrawImageUnscaled(original,0,0);}
     // Removes stray transparent-edge pixels in the original upper margin.
     for(int y=0;y<4;y++)for(int x=0;x<W;x++)tail.SetPixel(x,y,x<S?tile.GetPixel(x,y):x>=W-S?tile.GetPixel(W-1-x,y):Color.Transparent);
     tail.Save(Path.Combine(output,"coda.png"),ImageFormat.Png);
    }
   }
  }
  using(var reference=new Bitmap(Path.Combine(output,"fascia-1.png")))using(var head=new Bitmap(Path.Combine(output,"testa.png")))using(var tail=new Bitmap(Path.Combine(output,"coda.png"))){
   for(int i=1;i<=6;i++)using(var band=new Bitmap(Path.Combine(output,"fascia-"+i+".png"))){
    if(band.Width!=W||band.Height!=H)throw new Exception("Dimensioni fascia "+i);
    for(int x=0;x<W;x++){
     if(!SamePixel(band.GetPixel(x,0),reference.GetPixel(x,0))||!SamePixel(band.GetPixel(x,H-1),reference.GetPixel(x,H-1)))throw new Exception("Aggancio incompatibile fascia "+i);
    }
   }
   for(int x=0;x<W;x++){
    if(!SamePixel(head.GetPixel(x,Head-1),reference.GetPixel(x,H-1)))throw new Exception("Aggancio testata");
    if(!SamePixel(tail.GetPixel(x,0),reference.GetPixel(x,0)))throw new Exception("Aggancio coda a x="+x);
   }
  }
  Console.WriteLine("Sei fasce native 2172×360. Agganci di tutte le varianti, testata e coda verificati pixel per pixel.");
 }
}
'@
[ShortPaintedFrame]::Build((Split-Path $PSScriptRoot -Parent))

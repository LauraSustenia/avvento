$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$references=@([AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES').Split([IO.Path]::PathSeparator))
$references+=@([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { -not $_.IsDynamic -and $_.Location } | ForEach-Object Location)
Add-Type -ReferencedAssemblies ($references | Select-Object -Unique) -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.IO;
public static class RasterFrame {
  static int W=2172;
  static Bitmap Load(string path) {
    using(var source=new Bitmap(path)) {
      var result=new Bitmap(W,(int)Math.Round(source.Height*(double)W/source.Width),PixelFormat.Format32bppArgb);
      using(var g=Graphics.FromImage(result)) {g.CompositingMode=CompositingMode.SourceCopy;g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(source,new Rectangle(0,0,result.Width,result.Height));}
      return result;
    }
  }
  static bool Wood(Color c) {return c.A>96&&c.R-c.B>18&&c.R>c.G*.94&&c.G>c.B*.9;}
  static double[] Ports(Bitmap b,bool top,bool right,out int row) {
    int lo=right?(int)(W*.87):0,hi=right?W:(int)(W*.13);
    double wanted0=W*(right?.95:.035),wanted1=W*(right?.965:.05);
    for(int d=0;d<Math.Min(120,b.Height/4);d++) {
      int y=top?d:b.Height-1-d;
      var centers=new double[128];int centerCount=0,start=-1,last=-1,count=0;double total=0;
      for(int x=lo;x<hi+4;x++) {
        bool brown=x<hi&&b.GetPixel(x,y).A>48;
        if(brown) {if(start<0)start=x;last=x;count++;total+=x;}
        if(start>=0&&x-last>2){if(count>=3)centers[centerCount++]=total/count;start=-1;count=0;total=0;}
      }
      if(centerCount>=2) {
        double score=double.MaxValue,a=0,z=0;
        for(int i=0;i<centerCount;i++)for(int j=i+1;j<centerCount;j++) {
          double s=Math.Pow(centers[i]-wanted0,2)+Math.Pow(centers[j]-wanted1,2);
          if(s<score){score=s;a=centers[i];z=centers[j];}
        }
        int opaqueA=0,opaqueZ=0;
        for(int dx=-12;dx<=12;dx++){
          int ax=(int)Math.Round(a)+dx,zx=(int)Math.Round(z)+dx;
          if(ax>=0&&ax<W&&b.GetPixel(ax,y).A>220)opaqueA++;
          if(zx>=0&&zx<W&&b.GetPixel(zx,y).A>220)opaqueZ++;
        }
        if(opaqueA<11||opaqueZ<11)continue;
        row=y;return new[]{a,z};
      }
    }
    row=top?0:b.Height-1;return new[]{wanted0,wanted1};
  }
  static Color Mix(Color a,Color b,double t) {
    double aa=a.A/255.0*(1-t),ba=b.A/255.0*t,alpha=aa+ba;
    if(alpha<.00001)return Color.FromArgb(0,0,0,0);
    return Color.FromArgb((int)Math.Round(alpha*255),(int)Math.Round((a.R*aa+b.R*ba)/alpha),(int)Math.Round((a.G*aa+b.G*ba)/alpha),(int)Math.Round((a.B*aa+b.B*ba)/alpha));
  }
  static Color Sample(Bitmap b,double x,double y) {
    x=Math.Max(0,Math.Min(b.Width-1,x));y=Math.Max(0,Math.Min(b.Height-1,y));
    int x0=(int)x,y0=(int)y,x1=Math.Min(x0+1,b.Width-1),y1=Math.Min(y0+1,b.Height-1);
    return Mix(Mix(b.GetPixel(x0,y0),b.GetPixel(x1,y0),x-x0),Mix(b.GetPixel(x0,y1),b.GetPixel(x1,y1),x-x0),y-y0);
  }
  static double Map(double x,double[] target,double[] source) {
    int k=0;while(k<target.Length-2&&x>target[k+1])k++;
    return source[k]+(x-target[k])/(target[k+1]-target[k])*(source[k+1]-source[k]);
  }
  static double[] RowPorts(Bitmap b,int y,bool right,double[] expected) {
    int lo=right?(int)(W*.87):0,hi=right?W:(int)(W*.13);
    var centers=new double[128];int n=0,start=-1,last=-1,count=0;double total=0;
    for(int x=lo;x<hi+4;x++) {
      bool brown=x<hi&&b.GetPixel(x,y).A>48;
      if(brown){if(start<0)start=x;last=x;count++;total+=x;}
      if(start>=0&&x-last>2){if(count>=3)centers[n++]=total/count;start=-1;count=0;total=0;}
    }
    double best=double.MaxValue;var result=(double[])expected.Clone();
    for(int i=0;i<n;i++)for(int j=i+1;j<n;j++){
      double score=Math.Pow(centers[i]-expected[0],2)+Math.Pow(centers[j]-expected[1],2);
      if(score<best){best=score;result=new[]{centers[i],centers[j]};}
    }
    return result;
  }
  static double Radius(Bitmap b,double center,int y) {
    int c=(int)Math.Round(center),left=c,right=c;
    while(left>0&&c-left<24&&b.GetPixel(left-1,y).A>24)left--;
    while(right<W-1&&right-c<24&&b.GetPixel(right+1,y).A>24)right++;
    return Math.Max(3,(right-left+1)/2.0);
  }
  static Bitmap Align(Bitmap source,bool top,bool bottom) {
    var result=(Bitmap)source.Clone();int depth=Math.Min(96,source.Height/4);
    foreach(bool upper in new[]{true,false}) {
      if((upper&&!top)||(!upper&&!bottom))continue;
      foreach(bool right in new[]{false,true}) {
        int anchor;double[] ports=Ports(source,upper,right,out anchor);
        int lo=right?(int)(W*.87):0,hi=right?W:(int)(W*.13);
        double canonical0=W*(right?.95:.035),canonical1=W*(right?.965:.05);
        for(int d=0;d<depth;d++) {
          int y=upper?d:source.Height-1-d,edge=upper?0:source.Height-1;
          double t=d/(double)depth;
          // Tangente verticale al bordo, senza la piega creata dalla transizione lineare.
          double weight=1-(6*Math.Pow(t,5)-15*Math.Pow(t,4)+10*Math.Pow(t,3));
          double sampleY=y+(anchor-edge)*weight;
          int row=(int)Math.Round(sampleY);
          double[] actual=RowPorts(source,row,right,ports);
          double center0=actual[0]+(canonical0-actual[0])*weight,center1=actual[1]+(canonical1-actual[1])*weight;
          double r0=Math.Min(Radius(source,actual[0],row),(actual[1]-actual[0])*.38),r1=Math.Min(Radius(source,actual[1],row),(actual[1]-actual[0])*.38);
          double targetR0=Math.Min(r0+(10-r0)*weight,(center1-center0)*.4),targetR1=Math.Min(r1+(10-r1)*weight,(center1-center0)*.4);
          double[] target={lo,center0-targetR0,center0,center0+targetR0,center1-targetR1,center1,center1+targetR1,hi-1};
          double[] input={lo,actual[0]-r0,actual[0],actual[0]+r0,actual[1]-r1,actual[1],actual[1]+r1,hi-1};
          for(int x=lo;x<hi;x++)result.SetPixel(x,y,Sample(source,Map(x,target,input),sampleY));
        }
      }
    }
    return result;
  }
  static void Join(Bitmap b,Color[] port,bool top,bool bottom) {
    const int depth=12;
    foreach(bool upper in new[]{true,false}) {
      if((upper&&!top)||(!upper&&!bottom))continue;
      for(int d=0;d<depth;d++) {
        int y=upper?d:b.Height-1-d;
        double t=d<3?1:Math.Pow(1-(d-3)/(double)(depth-3),2);
        for(int x=0;x<W;x++) {
          if(d<3){b.SetPixel(x,y,port[x]);continue;}
          // Aggiunge il legno del raccordo senza cancellare i bordi dipinti con una sfumatura trasparente.
          Color original=b.GetPixel(x,y),reference=port[x];
          if(reference.A==0)continue;
          Color blended=Mix(original,reference,t);
          b.SetPixel(x,y,Color.FromArgb(Math.Max(original.A,blended.A),blended.R,blended.G,blended.B));
        }
      }
      // Ripristina l'opacità del legno dipinto vicino al taglio, senza riempire lo sfondo trasparente.
      for(int d=3;d<48;d++){
        int y=upper?d:b.Height-1-d;
        double strength=d<24?1:(48-d)/24.0;
        for(int x=0;x<W;x++){
          if(x>W*.13&&x<W*.87)continue;
          Color c=b.GetPixel(x,y);
          if(c.A>64){
            int alpha=(int)Math.Round(c.A+(255-c.A)*strength);
            b.SetPixel(x,y,Color.FromArgb(alpha,c.R,c.G,c.B));
          }
        }
      }
    }
  }
  static Bitmap AddBehind(Bitmap original,Bitmap edited,bool head) {
    var result=(Bitmap)original.Clone();
    for(int y=0;y<result.Height;y++) {
      double p=y/(double)result.Height;
      double gate=head?Math.Max(0,Math.Min(1,(p-.68)/.08)):Math.Max(0,Math.Min(1,(.60-p)/.18));
      if(gate<=0)continue;
      for(int x=0;x<W;x++) {
        if(x>W*.10&&x<W*.90)continue;
        Color a=original.GetPixel(x,y),e=Sample(edited,x,y*edited.Height/(double)result.Height);
        if(head){result.SetPixel(x,y,Mix(a,e,gate));continue;}
        double aa=a.A/255.0,ea=e.A/255.0*gate*(1-aa),alpha=aa+ea;
        if(alpha<=.00001)continue;
        result.SetPixel(x,y,Color.FromArgb((int)Math.Round(alpha*255),(int)Math.Round((a.R*aa+e.R*ea)/alpha),(int)Math.Round((a.G*aa+e.G*ea)/alpha),(int)Math.Round((a.B*aa+e.B*ea)/alpha)));
      }
    }
    return result;
  }
  public static void Build(string root) {
    string source=Path.Combine(root,"scripts","frame-source"),output=Path.Combine(root,"images","cornice-png");
    Directory.CreateDirectory(output);var port=new Color[W];
    using(var raw=Load(Path.Combine(source,"fascia-3.png")))using(var first=Align(raw,true,true)) {
      for(int x=0;x<W;x++)port[x]=Color.FromArgb(0,0,0,0);
      foreach(double fraction in new[]{.035,.05,.95,.965}){
        int center=(int)Math.Round(W*fraction);Color core=first.GetPixel(center,0);
        for(int dx=-10;dx<=10;dx++){
          Color c=first.GetPixel(center+dx,0);if(c.A<180)c=core;
          int alpha=Math.Abs(dx)<=8?255:(Math.Abs(dx)==9?190:60);
          port[center+dx]=Color.FromArgb(alpha,c.R,c.G,c.B);
        }
      }
    }
    for(int i=1;i<=6;i++)using(var raw=Load(Path.Combine(source,"fascia-"+i+".png")))using(var aligned=Align(raw,true,true)) {
      Join(aligned,port,true,true);aligned.Save(Path.Combine(output,"fascia-"+i+".png"),ImageFormat.Png);
      Console.WriteLine("Fascia "+i+": "+aligned.Width+"x"+aligned.Height);
    }
    foreach(string name in new[]{"testa","coda"})using(var original=Load(Path.Combine(root,"images",name+".png")))using(var edited=Load(Path.Combine(source,name+".png")))using(var combined=AddBehind(original,edited,name=="testa"))using(var aligned=Align(combined,name=="coda",name=="testa")) {
      Join(aligned,port,name=="coda",name=="testa");aligned.Save(Path.Combine(output,name+".png"),ImageFormat.Png);
    }
    // Verifica tutti i 36 abbinamenti: ogni riga di raccordo deve essere identica.
    foreach(string file in Directory.GetFiles(output,"*.png"))using(var b=new Bitmap(file)) {
      bool head=Path.GetFileName(file)=="testa.png",tail=Path.GetFileName(file)=="coda.png";
      for(int x=0;x<W;x++) {
        if(!head&&b.GetPixel(x,0).ToArgb()!=port[x].ToArgb())throw new Exception("Raccordo superiore: "+file);
        if(!tail&&b.GetPixel(x,b.Height-1).ToArgb()!=port[x].ToArgb())throw new Exception("Raccordo inferiore: "+file);
      }
    }
    Console.WriteLine("Raccordi raster verificati: sei fasce, testa e coda.");
  }
}
'@
[RasterFrame]::Build((Split-Path $PSScriptRoot -Parent))

// SquiggleDraw
//
// A processing sketch by Gregg Wygonik
//
// https://github.com/gwygonik/SquiggleDraw


/* 
 
 Additional credits
 
 Contributions by Maksim Surguy 
 https://github.com/msurguy
 
 Contributions by Ivan Moroz (sNow)
 https://github.com/sNow32/a
 
 Contributions by Windell H. Oskay
 www.evilmadscientist.com
 https://github.com/evil-mad/
 
 */


import processing.svg.*;

PImage p1;
PImage p2;

// sldLines
int ystep = 120;
// sldAmplitude
int ymult = 4;
// sldXSpacing: = 31 - 28
int xstep = 3;
// xsldXFrequency: = 257.0 - 128
float xsmooth = 129.0;
// sldImgScale
int imageScaleUp = 3;

float r = 0.0;
float a = 0.0;

// lineWidth
int strokeWidth = 5;

float startx, starty, z;

int b, oldb;
// maxBrightness
int maxB = 255;
// minBrightness
int minB = 0;

boolean isRunning = true;
boolean isRecording = false;
boolean needsReload = true;

//boolean isInit = false;
// tglInvert
boolean invert = false;
// tglConnect
boolean connectEnds = true;

String imageName = "";

void setup() {
  surface.setVisible(false);

  if (args.length == 0) {
    println("Missing image full path");
    exit();
  }

  imageName = args[0];
  loadMainImage(imageName);
  createSecondaryImage();
  isRecording = true;
  isRunning = true;
  needsReload = false;

  // save to file
  // was: beginRecord(SVG, "squiggleImage_" + millis() + ".svg");
  String[] p = splitTokens(imageName, "."); // split by point to know path without suffix
  // save to dir where is opening file
  String savePath = p[p.length - 2] + ".svg";           
  println(savePath);
  beginRecord(SVG, savePath);
  createPic();
  exit();
}

void loadMainImage(String inImageName) {
  p1 = loadImage(inImageName);

  surface.setSize(p1.width, p1.height);

  // filter image
  p1.filter(GRAY);
  p1.filter(BLUR, 2);
  if (invert) {
    p1.filter(INVERT);
  }

  needsReload = true;
}

void createSecondaryImage() {
  p2 = createImage(p1.width*imageScaleUp, p1.height*imageScaleUp, ALPHA);
  p2.copy(p1, 0, 0, p1.width, p1.height, 0, 0, p1.width*imageScaleUp, p1.height*imageScaleUp);
}

void createPic() {


  stroke(0);
  noFill();
  strokeWeight(strokeWidth);

  startx = 0.0;
  starty = 0.0;

  if (!isRecording)
    background(255);

  float scaleFactor = 1.0/imageScaleUp;
  float xOffset = isRecording ? 0 : 150;

  float deltaPhase;
  float deltaX;
  float deltaAmpl;

  /*
   The minimum phase increment should give about 40 vertices minimum
   across x. 40 vertices -> 10 * 2 pi. 
   */
  float minPhaseIncr = 10 * TWO_PI / (p2.width / xstep);

  /*
    Maximum phase increment (frequency cap) is based on line thickness and x step size.
   
   A full period of oscillation needn't be less than 
   2 * strokeWidth in total width.
   
   The maximum number of full cycles that should be permitted in a 
   horizontal distance of xstep should be:
   N = total width/width per cycle =  xstep / (2 * strokeWidth)
   
   The maximum phase increment in distance xstep should then be:
   
   maxPhaseIncr = 2 Pi * N = 2 * Pi *  xstep / (2 * strokeWidth) 
   = 2Pi *  xstep / strokeWidth
   
   We do not need to include the scaling factors, since
   both the step size and stroke width are scaled the same way.
   */


  float maxPhaseIncr =  TWO_PI * xstep / strokeWidth;

  strokeWeight(strokeWidth * scaleFactor);

  if (connectEnds)
  {    
    beginShape();
  }

  boolean oddRow = false;
  boolean finalRow = false;
  boolean reverseRow;
  float lastX;
  float scaledYstep = p2.height/ystep;

  for (int y=0; y<p2.height; y+=scaledYstep) {

    if (!connectEnds)
    {    
      beginShape();
    }

    oddRow = !oddRow;
    if (y + (scaledYstep ) >= p2.height)
      finalRow = true;

    if (connectEnds && !oddRow)
      reverseRow = true;
    else
      reverseRow = false;

    a = 0.0;

    // Add initial "extra" point to give splines a consistent visual endpoint,
    // IF we are not connecting rows.

    if (reverseRow)
    {
      if (!connectEnds || y == 0)    
      {
        // Always add the extra initial point if we're not connecting the ends, or if this is the first row.
        curveVertex(xOffset + scaleFactor * (p2.width + 0.1 * xstep), scaleFactor * y);
      }
      curveVertex(xOffset + scaleFactor * (p2.width), scaleFactor * y);
    } else
    {
      if (!connectEnds || y == 0)    
      {
        // Always add the extra initial point if we're not connecting the ends, or if this is the first row.
        curveVertex(xOffset - scaleFactor * ( 0.1 * xstep), y * scaleFactor);
      }
      curveVertex(xOffset, y * scaleFactor);
    }



    /*
    Step along width of image.
     
     For each step, get the image brightness for that XY position,
     and constrain it to our bright/dark cutoff window.
     
     Accumulated phase: increment by scaled brightness, so that the frequency
     increases in certain areas of the image.  Phase only advances with pigment,
     not simply by traversing across the image in X.
     
     Amplitude: A simple multiplier based on local brightness.
     
     To have high quality generated curves for display and plotting, we would like to:
     
     (1) Avoid aliasing. Aliasing happens when we plot a signal at a poorly
     representative set of points. By undersampling -- e.g., less than once per
     period -- you can very easily see what appears to be a sine wave, but does
     not actually represent the actual function being sampled.
     
     Two potential methods to avoid aliasing:
     (A) Increase the number of points, to ensure that some minimum number
     of points are sampeled per period, or 
     (B) Plot the function at specific points {x_i} that are determined by
     the value of the function f(x) at those points, e.g., at every crest, 
     trough, and zero crossing.
     
     (2) Place relatively few control points. 
     CNC software tends to follow simply defined curves more easily than 
     paths with a great many closely-spaced points. 
     Side benefit: Potentially smaller file size.
     
     (3) Place an upper bound on the maximum frequency.
     Above a certain frequency, with a finite-width pen, increasing the frequency
     does not make the plot any darker. 
     
     
     To achieve these goals, we will try: 
     
     (1) Putting x-points (vertices) at every crest, trough, and zero crossing. 
     Point x-positions may be approximated as necessary by interpolation.
     
     (2) Using Processing's curveVertex method, to create curvy lines
     (Catmull–Rom splines). These will only approximate sine waves, but 
     should work well for this particular application.
     
     (3) Using the GUI line-width control to control the maximum frequency.
     
     */

    float phase = 0.0;
    float lastPhase = 0; // accumulated phase at previous vertex
    float lastAmpl = 0; // amplitude at previous vertex
    boolean finalStep = false;

    int x;

    x = 1;
    lastX = 1;

    float[] xPoints = new float[0]; 
    float[] yPoints = new float[0];

    while (finalStep == false) { // Iterate over each each x-step in the row

      // Moving right to left:
      x += xstep;
      if (x + xstep >= p2.width)
        finalStep = true;
      else
        finalStep = false;
      
      b = (int)alpha(p2.get(x, y));
      b = max(minB, b);
      z = max(maxB-b, 0);        // Brightness trimmed to range.

      r = z/ystep*ymult;        // ymult: Amplitude

      /*
       Enforce a minimum phase increment, to prevent large gaps in splines 
       This will add extra vertices in flat regions, but the amplitude remains
       unaffected (near-zero amplitude), so it does not cause a significant
       visual effect.
       */

      float df = z/xsmooth;
      if (df < minPhaseIncr)
        df = minPhaseIncr;

      /*
       Enforce a maximum phase increment -- a frequency cap -- to prevent 
       unnecessary plotting time. Once the frequency is so high that the line widths
       of neighboring crests overlap, there is no added benefit to having higher
       frequency; it's just wasting memory (and ink + time, if plotting).
       */

      if (df > maxPhaseIncr)
        df = maxPhaseIncr;

      phase += df;  // xsmooth: Frequency

      deltaX = x - lastX; // Distance between image sample location x and previous vertex

      deltaAmpl = r - lastAmpl;

      deltaPhase = phase - lastPhase; // Change in phase since last *vertex*
      // (Vertices do not fall along the x "grid", but where they need to.)

      if (!finalStep)  // Skip to end points if this is the last point in the row.
        if (deltaPhase > HALF_PI) // Only add vertices if true.
        {
          /* 
           Linearly interpolate phase and amplitude since last vertex added.
           This treats the frequency as constant
           between subsequent x-samples of the source image.
           */

          int vertexCount = floor( deltaPhase / HALF_PI); //  Add this many vertices

          float integerPart = ((vertexCount * HALF_PI) / deltaPhase);
          // "Integer" fraction (in terms of pi/2 phase segments) of deltaX.

          float deltaX_truncate = deltaX * integerPart;
          // deltaX_truncate: "Integer" part (in terms of pi/2 segments) of deltaX.

          float xPerVertex =  deltaX_truncate / vertexCount;
          float amplPerVertex = (integerPart * deltaAmpl) / vertexCount;

          // Add the vertices:
          for (int i = 0; i < vertexCount; i = i+1) {

            lastX = lastX + xPerVertex;
            lastPhase = lastPhase + HALF_PI;
            lastAmpl = lastAmpl + amplPerVertex;

            xPoints =  append(xPoints, xOffset + scaleFactor * lastX); 
            yPoints =  append(yPoints, scaleFactor *(y+sin(lastPhase)*lastAmpl));
          }
        }
    }
    if (reverseRow) {
      xPoints = reverse(xPoints);
      yPoints = reverse(yPoints);
    }

    for (int i = 0; i < xPoints.length; i++) {
      curveVertex(xPoints[i], yPoints[i]);
    }
    // Add final "extra" point to give splines a consistent visual endpoint:
    if (reverseRow)
    {
      curveVertex(xOffset, y * scaleFactor);
      if (!connectEnds || finalRow)    
      {
        // Always add the extra final point if we're not connecting the ends, or if this is the first row.
        curveVertex(xOffset - scaleFactor * ( 0.1 * xstep), y * scaleFactor);
      }
    } else
    {
      curveVertex(xOffset + scaleFactor * (p2.width), scaleFactor * y);
      if (!connectEnds || finalRow)    
      {
        // Always add the extra final point if we're not connecting the ends, or if this is the first row.
        curveVertex(xOffset + scaleFactor * (p2.width + 0.1 * xstep), scaleFactor * y);
      }
    }


    if (connectEnds && !finalRow)  // Add curvy end connectors
      if (reverseRow)
      {
        curveVertex(xOffset - scaleFactor * ( 0.1 * xstep + scaledYstep/3), (y + scaledYstep/2) * scaleFactor );
      } else
      {
        curveVertex(xOffset + scaleFactor * (p2.width + 0.1 * xstep + scaledYstep/3), (y + scaledYstep/2) * scaleFactor );
      }


    if (!connectEnds)
    {    
      endShape();
    }
  }

  if (connectEnds)
  {    
    endShape();
  }
}


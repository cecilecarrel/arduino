/**
 * Records accelerometer-based gestures. Works with the Arduino program
 * ADXL335SerialWriter.ino, LISDHSerialWriter.ino or any program that 
 * provides a CSV input stream on the serial port of "timestamp, x, y, z"
 *
 * Program assumes integer values coming over Serial
 *   
 * By Jon E. Froehlich
 * @jonfroehlich
 * http://makeabilitylab.io
 * 
 */
 
import processing.serial.*;
import java.awt.Rectangle;
import java.io.BufferedWriter;
import java.io.FileWriter;

final String FULL_DATASTREAM_RECORDING_FILENAME = "arduino_accel.csv";

final color GRID_COLOR = color(128, 128, 128);
final color XCOLOR = color(255, 61, 0, 200);
final color YCOLOR = color(73, 164, 239, 200);
final color ZCOLOR = color(255, 183, 0, 200);
final color [] SENSOR_VALUE_COLORS = { XCOLOR, YCOLOR, ZCOLOR };
final color DEFAULT_BACKGROUND_COLOR = color(44, 42, 41);
final int DISPLAY_TIMEWINDOW_MS = 1000 * 30; // 30 secs. You can change this to view more data


// Make sure to change this! If you're not sure what port your Arduino is using
// Run this Processing sketch and look in the console, then change the number accordingly
final int ARDUINO_SERIAL_PORT_INDEX = 0; 

ArrayList<AccelSensorData> _displaySensorData =  new ArrayList<AccelSensorData>(); // sensor data displayed to screen
PrintWriter _printWriterAllData;

// The serial port is necessary to read data in from the Arduino
Serial _serialPort;

long _currentXMin; // the far left x-axis value on the graph
Rectangle _legendRect; // location and drawing area of the legend
boolean _dynamicYAxis = true;
int _minSensorVal = 0;
int _maxSensorVal = 1023;

void setup() {
  size(1024, 576);

  // Print to console all the available serial ports
  String [] serialPorts = getAndPrintSerialPortInfo();
  
  if(serialPorts.length <= 0){
    println("You appear to have *ZERO* active serial ports. Make sure your Arduino is plugged in. Exiting...");
    exit();
  }else if(ARDUINO_SERIAL_PORT_INDEX > serialPorts.length){
    println("You set ARDUINO_SERIAL_PORT_INDEX = " + ARDUINO_SERIAL_PORT_INDEX + "; however, you only have " +
            serialPorts.length + " total serial ports.");
    println("Please make sure your Arduino is plugged in. Then update ARDUINO_SERIAL_PORT_INDEX to the appropriate index.");
    println("Exiting...");
    exit();
    return;
  }
  
  // Open the serial port
  try{
    println("Attempting to initialize the serial port at index " + ARDUINO_SERIAL_PORT_INDEX);
    println("This index corresponds to serial port " + serialPorts[ARDUINO_SERIAL_PORT_INDEX]);
    _serialPort = new Serial(this, serialPorts[ARDUINO_SERIAL_PORT_INDEX], 9600);
  }catch(Exception e){
    println("Serial port exception: " + e);
    e.printStackTrace();
    exit();
    return;
  }

  if(_serialPort == null){
    println("Could not initialize the serial port at " + ARDUINO_SERIAL_PORT_INDEX + ". Exiting...");
    exit();
    return;
  }
  
  // Don't generate a serialEvent() unless you get a newline character:
  _serialPort.bufferUntil('\n');

  _currentXMin = System.currentTimeMillis() - DISPLAY_TIMEWINDOW_MS;

  int legendHeight = 60;
  int legendWidth = 200;
  int legendXBuffer = 60;
  int legendYBuffer = 5;
  
  //_legendRect = new Rectangle(width - legendWidth - legendXBuffer, legendYBuffer, legendWidth, legendHeight); // legend at top-right
  _legendRect = new Rectangle(legendXBuffer, legendYBuffer, legendWidth, legendHeight); // legend at top-left
  
  String fileNameWithPath = sketchPath(FULL_DATASTREAM_RECORDING_FILENAME);
  File file = new File(fileNameWithPath); 
  println("Saving accel data to: " + fileNameWithPath);
     
  try {
    // We save all incoming sensor data to a file (by appending)
    // Appending text to a file: 
    //  - https://stackoverflow.com/questions/17010222/how-do-i-append-text-to-a-csv-txt-file-in-processing
    //  - https://docs.oracle.com/javase/7/docs/api/java/io/FileWriter.html
    //  - Use sketchPath(string) to store in local sketch folder: https://stackoverflow.com/a/36531925
    _printWriterAllData = new PrintWriter(new BufferedWriter(new FileWriter(file, true)));
  }catch (IOException e){
    e.printStackTrace();
  }

  // disable automatically looping over draw()
  // instead, only redraw when we have new data...
  noLoop(); 
  
  println("Waiting for Serial data...");
}

void draw() {
  
  background(DEFAULT_BACKGROUND_COLOR);
 
  if(_displaySensorData.size() <= 0){
    textSize(50);
    
    String strInstructions = "Waiting for Serial data...";
    float strWidth = textWidth(strInstructions);
    float strHeight = textAscent() + textDescent();

    fill(255);
    text(strInstructions, width / 2.0 - strWidth / 2.0, height / 4.0 + strHeight / 2.0 - textDescent());
  }
 
  drawYAxis();
  
  //println("Drawing! _displaySensorData.size()=" + _displaySensorData.size() + " _timeWindowMs=" + _timeWindowMs);
  for (int i = 1; i < _displaySensorData.size(); i++) {
    AccelSensorData lastAccelSensorData = _displaySensorData.get(i - 1);
    AccelSensorData curAccelSensorData = _displaySensorData.get(i);

    drawSensorLine(XCOLOR, lastAccelSensorData.timestamp, lastAccelSensorData.x, curAccelSensorData.timestamp, curAccelSensorData.x);
    drawSensorLine(YCOLOR, lastAccelSensorData.timestamp, lastAccelSensorData.y, curAccelSensorData.timestamp, curAccelSensorData.y);
    drawSensorLine(ZCOLOR, lastAccelSensorData.timestamp, lastAccelSensorData.z, curAccelSensorData.timestamp, curAccelSensorData.z);
  }

  drawLegend(_legendRect);
}

void drawYAxis(){
  int numYTickMarks = 5; 
  
  noFill();
  stroke(GRID_COLOR);
  textSize(10);
  float strHeight = textAscent() + textDescent();
  float yRange = getYRange();
  float yTickStep = yRange / numYTickMarks;
  for(int yTickMark = 0; yTickMark < numYTickMarks; yTickMark++){
    float yVal = map(yTickMark, 0, numYTickMarks, _minSensorVal + yRange * 0.10, _maxSensorVal - yRange * 0.10);
    float yCurPixelVal = getYPixelFromSensorVal(yVal);
    line(0, yCurPixelVal, 10, yCurPixelVal);
  }
}

/**
 * Get full yrange
 */
float getYRange(){
  return _maxSensorVal - _minSensorVal; 
}

/**
 * Prints information about the serial port and returns a list of all available serial ports
 */
String[] getAndPrintSerialPortInfo(){
  println("** All Available Serial Ports **");
  String[] listOfSerialPorts = Serial.list();
  printArray(listOfSerialPorts);
  println("** END SERIAL PORT LIST**");
  println("Make sure to change ARDUINO_SERIAL_PORT_INDEX to the correct port number!");
  
  if(listOfSerialPorts.length > 0){
    String firstPortName = listOfSerialPorts[0];
    println("For example, if your Arduino is on port " + firstPortName + 
            " then you would set ARDUINO_SERIAL_PORT_INDEX = " + 0);
  }
  return listOfSerialPorts;
}

/**
 * Converts a sensor value to a y-pixel value and returns the y-pixel value
 */
float getYPixelFromSensorVal(int sensorVal) {
  return map(sensorVal, _minSensorVal, _maxSensorVal, 0, height);
}

/**
 * Converts a sensor value to a y-pixel value and returns the y-pixel value
 */
float getYPixelFromSensorVal(float sensorVal) {
  return map(sensorVal, _minSensorVal, _maxSensorVal, 0, height);
}

/**
 * Converts a timestamp value to an x-pixel value and returns the x-pixel value
 */
float getXPixelFromTimestamp(long timestamp) {
  return (timestamp - _currentXMin) / (float)DISPLAY_TIMEWINDOW_MS * width;
}

/**
 * Draws a sensor line with the given color
 */
void drawSensorLine(color col, long timestamp1, int sensorVal1, long timestamp2, int sensorVal2) {
  stroke(col);
  strokeWeight(2);
  float xLastPixelVal = getXPixelFromTimestamp(timestamp1);
  float yLastPixelVal = getYPixelFromSensorVal(sensorVal1);
  float xCurPixelVal = getXPixelFromTimestamp(timestamp2);
  float yCurPixelVal = getYPixelFromSensorVal(sensorVal2); 
  line(xLastPixelVal, yLastPixelVal, xCurPixelVal, yCurPixelVal);
}

/**
 * Draws the graph legend, which is dynamic based on the current sensor values
 */
void drawLegend(Rectangle legendRect) {
  if(_displaySensorData.size() <= 0){
    return;
  }
  
  color textColor = color(255, 255, 255, 128);
  
  // draw outline of legend box
  stroke(textColor);
  strokeWeight(1);
  noFill();
  rect(legendRect.x, legendRect.y, legendRect.width, legendRect.height);

  // Setup dimension calculations for legend
  int yBuffer = 4;
  int xBuffer = 4;
  int numLegendItems = 3;
  float legendItemHeight = (legendRect.height - (numLegendItems * yBuffer)) / (float)numLegendItems;  
  String [] legendStrs = { "X", "Y", "Z" };
  textSize(legendItemHeight);
  float strHeight = textAscent() + textDescent();
  float yLegendItemPos = legendRect.y + strHeight - textDescent();
  AccelSensorData accelSensorData = _displaySensorData.get(_displaySensorData.size() - 1);
  int [] accelSensorVals = accelSensorData.getSensorValues();
  
  float titleWidth = textWidth("X");
  float maxValStrWidth = textWidth(Integer.toString(_maxSensorVal));
  float minValStrWidth = textWidth(Integer.toString(_minSensorVal));
  
  float largestValStrWidth = max(minValStrWidth, maxValStrWidth);
    
  if(_minSensorVal < 0){
    // if we have values less than zero, then we split the legend in half
    // and draw the < 0 values to the left of the titles and the > 0
    // to the right of the values
    
    float xMidLegend = legendRect.x + legendRect.width / 2.0;
    float xTitleStart = xMidLegend - titleWidth / 2.0;
    float maxBarSize = legendRect.width / 2.0 - (2 * xBuffer + titleWidth + 3 * xBuffer + largestValStrWidth);
    
    for (int i = 0; i < legendStrs.length; i++) {
      String legendStr = legendStrs[i];
      fill(textColor);
      text(legendStr, xTitleStart, yLegendItemPos);
      
      // draw the bar
      fill(SENSOR_VALUE_COLORS[i]);
      noStroke();
      float barWidth = map(accelSensorVals[i], _minSensorVal, 0, 0, maxBarSize);
      float xBar = xTitleStart - xBuffer - barWidth;
      String strSensorVal = Integer.toString(accelSensorVals[i]);
      float xSensorTextLoc = xBar - largestValStrWidth;
      if(accelSensorVals[i] > 0){
        barWidth = map(accelSensorVals[i], 0, _maxSensorVal, 0, maxBarSize);
        xBar = xMidLegend + titleWidth / 2.0 + xBuffer;
        xSensorTextLoc = xBar + barWidth + xBuffer;
      }
      rect(xBar, yLegendItemPos - strHeight + textDescent() + yBuffer, barWidth, legendItemHeight - yBuffer); 
      
      // draw the sensor val
      text(strSensorVal, xSensorTextLoc, yLegendItemPos);
      yLegendItemPos += legendItemHeight + yBuffer;
    }  
  }else{
    // no values < 0, so draw legend normally
    
    float xLegendItemPos = legendRect.x + xBuffer;
    float xBar = xLegendItemPos + titleWidth + xBuffer;
    float maxBarSize = legendRect.width - (xBuffer + titleWidth + 3 * xBuffer + maxValStrWidth);
    
    // Draw each legend item
    for (int i = 0; i < legendStrs.length; i++) {
      String legendStr = legendStrs[i];
      fill(textColor);
      text(legendStr, xLegendItemPos, yLegendItemPos);
  
      // draw dynamic legend values
      float barWidth = map(accelSensorVals[i], _minSensorVal, _maxSensorVal, 0, maxBarSize);
      fill(SENSOR_VALUE_COLORS[i]);
      noStroke();
      rect(xBar, yLegendItemPos - strHeight + textDescent() + yBuffer, barWidth, legendItemHeight - yBuffer);
      float xSensorTextLoc = xBar + barWidth + xBuffer;
      text(Integer.toString(accelSensorVals[i]), xSensorTextLoc, yLegendItemPos);
      yLegendItemPos += legendItemHeight + yBuffer;
    }
  }
}
 //<>//
/**
 * Called automatically when there is data on the serial port
 * See: https://processing.org/reference/libraries/serial/serialEvent_.html
 */
void serialEvent (Serial myPort) {
  long currentTimestampMs = System.currentTimeMillis();
  _currentXMin = currentTimestampMs - DISPLAY_TIMEWINDOW_MS;

  String inString = "";
  try {
    // Grab the data off the serial port. See: 
    // https://processing.org/reference/libraries/serial/index.html
    inString = trim(_serialPort.readStringUntil('\n'));
    // println(inString);
  }
  catch(Exception e){
    println("Failed to read serial port. Exception below: ");
    println(e);
    return;
  }
  
  try{
    if (inString != null) {
      int [] data;

      // Our parser can handle either csv strings or just one float per line
      if (inString.contains(",")) {
        String [] strData = split(inString, ',');
        data = new int[strData.length];
        for(int i=0; i<strData.length; i++){
          data[i] = int(strData[i].trim()); 
        }
      } else {
        data = new int[] { int(inString) };
      }

      AccelSensorData accelSensorData = new AccelSensorData(currentTimestampMs, data[0], data[1], data[2], data[3]);
      checkAndSetNewMinMaxSensorValues(accelSensorData);
      
      _displaySensorData.add(accelSensorData);

      // Remove data that is no longer relevant to be displayed
      while(_displaySensorData.size() > 0 && 
            _displaySensorData.get(0).timestamp < _currentXMin){
        _displaySensorData.remove(0);
      }

      _printWriterAllData.println(accelSensorData.toCsvString());
      
      // force the redraw
      redraw();
    }
  }
  catch(Exception e) {
    println("Received '" + inString + "' but failed to parse. Exception below:");
    println(e);
  }
}

/**
 * Checks for new global min and max data in our sensor values
 */
void checkAndSetNewMinMaxSensorValues(AccelSensorData accelSensorData){
  int min = min(accelSensorData.x, accelSensorData.y, accelSensorData.z);
  int max = max(accelSensorData.x, accelSensorData.y, accelSensorData.z);
  if(min < _minSensorVal){
    _minSensorVal = min; 
  }
  
  if(max > _maxSensorVal){
    _maxSensorVal = max; 
  }
}

// Class for the accelerometer data
class AccelSensorData {
  public final static String CSV_HEADER = "Processing Timestamp (ms), Arduino Timestamp (ms), X, Y, Z";
  
  public int x;
  public int y;
  public int z;
  public long timestamp;
  public long arduinoTimestamp;

  public AccelSensorData(long timestamp, long arduinoTimestamp, int x, int y, int z) {
    this.timestamp = timestamp;
    this.arduinoTimestamp = arduinoTimestamp;
    this.x = x;
    this.y = y;
    this.z = z;
  }
  
  // Creates a dynamic array on every call
  public int[] getSensorValues(){
    return new int[] { this.x, this.y, this.z };
  }
  
  public String toCsvHeaderString(){
    return CSV_HEADER;
  }
  
  public String toCsvString(){
    return String.format("%d, %d, %d, %d, %d", this.timestamp, this.arduinoTimestamp, this.x, this.y, this.z);
  }

  public String toString() { 
    return String.format("timestamp=%d x=%d y=%d z=%d", this.timestamp, this.x, this.y, this.z);
  }
}
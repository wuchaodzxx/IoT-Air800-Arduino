#include <ArduinoJson.h>
#include <inttypes.h>
#include <Adafruit_GFX.h>    // Core graphics library
#include <Adafruit_ST7735.h> // Hardware-specific library
#include <SPI.h>
/*
 * LED
 */
 unsigned int LED = 13;
/*
 * DHT22配置程序
 */
unsigned int DHT_PIN = 7;

#define DHT_OK      1
#define DHT_ERR_CHECK 0
#define DHT_ERR_TIMEOUT -1
float humidity;
float temperature;


#define TFT_CS     10
#define TFT_RST    8  // you can also connect this to the Arduino reset ,in which case, set this #define pin to -1!
#define TFT_DC     9

Adafruit_ST7735 tft = Adafruit_ST7735(TFT_CS,  TFT_DC, TFT_RST);

//定义显示数据
//时间
String date_year="0000";
String date_month="00";
String date_day="00";
String date_hour="00";
String date_minute="00";
//温度
String temprature_00_00="+";
String temprature_10_00="0";
String temprature_01_00="0";
String temprature_00_10="0";
String temprature_00_01="0";
//湿度
String humidity_10_00="0";
String humidity_01_00="0";
String humidity_00_10="0";
String humidity_00_01="0";

//串口受到的数据放在以下几个变量中
String uart_date="";
String uart_asu="";


//串口接收数据
String  ReceiveData= "";
unsigned char DHT_read()
{
  // BUFFER TO RECEIVE
  unsigned char bits[5] = {0,0,0,0,0};
  unsigned char cnt = 7;
  unsigned char idx = 0;
  unsigned char sum;
  // REQUEST SAMPLE
  pinMode(DHT_PIN, OUTPUT);
  digitalWrite(DHT_PIN, LOW);
  delay(18);
  digitalWrite(DHT_PIN, HIGH);
  delayMicroseconds(40);
  pinMode(DHT_PIN, INPUT);

  // ACKNOWLEDGE or TIMEOUT
  unsigned int count = 10000;
  while(digitalRead(DHT_PIN) == LOW)
    if (count-- == 0) return DHT_ERR_TIMEOUT;

  count = 10000;
  while(digitalRead(DHT_PIN) == HIGH)
    if (count-- == 0) return DHT_ERR_TIMEOUT;

  // READ OUTPUT - 40 BITS => 5 BYTES or TIMEOUT
  for (int i=0; i<40; i++)
  {
    count = 10000;
    while(digitalRead(DHT_PIN) == LOW)
      if (count-- == 0) return DHT_ERR_TIMEOUT;

    unsigned long t = micros();

    count = 10000;
    while(digitalRead(DHT_PIN) == HIGH)
      if (count-- == 0) return DHT_ERR_TIMEOUT;

    if ((micros() - t) > 40) bits[idx] |= (1 << cnt);
    if (cnt == 0)   // next byte?
    {
      cnt = 7;    // restart at MSB
      idx++;      // next byte!
    }
    else cnt--;
  }

  sum = bits[0]+bits[1]+bits[2]+bits[3];
  if(bits[4] != sum) return DHT_ERR_CHECK;
    

  humidity = (float)((bits[0] << 8)+bits[1])/10;
  temperature = (float)((bits[2] << 8)+bits[3])/10;
  
  return DHT_OK;
}

void setup() {
   Serial.begin(115200,SERIAL_8N1);
   pinMode(LED,OUTPUT);//指示灯
   pinMode(DHT_PIN,INPUT);
   digitalWrite(DHT_PIN, HIGH);

  tft.initR(INITR_GREENTAB); 
  tft.fillScreen(ST7735_BLACK);
  LCD_Init();
}
unsigned long st=0;
void loop() {
   unsigned long starttime = millis();
   DHT_read();
   //
   String send_data;
   StaticJsonBuffer<200> jsonBuffer1;
   JsonObject& root1 = jsonBuffer1.createObject();
   root1["Temperature"] = String(temperature);
   root1["Humidity"] = String(humidity);
   root1.printTo(send_data);
   Serial.print(send_data);
   Serial.println("end");//数据发送完成后必须发送一个end字符串标记数据的结束   
   //
   //Serial.print(temperature);
   //Serial.print("-");
   //Serial.print(humidity);
   //Serial.println("end");//数据发送完成后必须发送一个end字符串标记数据的结束
   digitalWrite(LED,HIGH);
   digitalWrite(4,HIGH);
   delay(500); //Delay
   digitalWrite(LED,LOW);
   delay(500); //Delay

  unsigned long uart_start = millis();
  unsigned long uart_end;
  while(1){
    uart_end = millis();
    if((uart_end-uart_start)>=3000){
        ReceiveData="";
        break;
    }
      //读取串口数据，end为结尾标志
    if(Serial.available()>0)//如果串口有数据进入的话
    {
       ReceiveData +=  char (Serial.read());//每次读一个字符，是ASCII码的
       //Serial.println(ReceiveData);
       if(ReceiveData.lastIndexOf("end")>0){
          String tmp = ReceiveData;
          ReceiveData="";
  
          //日志
          //logs(tmp);
          //日志end
          //收到的数据是json格式
          StaticJsonBuffer<200> jsonBuffer2;
          JsonObject& root2 = jsonBuffer2.parseObject(tmp);
          if(root2.success()){
             // logs(root["Date"]);
             st++;
             String date = root2["Date"];
             String asu = root2["RSSI"];
             uart_date = date;
             uart_asu = asu;
             showRemoteDataOnLCD();
             break; 
          }else{
            //清除缓存，从新读
            while(Serial.available()>0){Serial.read();}            
          }
        }
    }
  }
 showLocalDataOnLCD();
}
void LCD_Init(){
    //标题框
    tft.fillScreen(ST7735_BLACK);
    tft.drawRect(0, 0, 128, 20, ST7735_GREEN);
    //标题内容
    tft.setTextWrap(false);
    tft.setCursor(25, 3);
    tft.setTextColor(ST7735_RED);
    tft.setTextSize(2);
    tft.println("Monitor");
    //数据框
    tft.drawRect(0, 22, 128, 137, ST7735_GREEN);
    //显示时间
    tft.setCursor(18, 28);
    tft.setTextSize(1);
    tft.setTextColor(ST7735_GREEN);
    tft.println("0000-00-00 00:00");
    tft.println(" ");
    //温度提示符
    tft.setCursor(4, 40);
    tft.setTextSize(1);
    tft.setTextColor(ST7735_YELLOW);
    tft.println("Temprature:");
    tft.println(" ");
    //湿度提示符
    tft.setCursor(4, 50);
    tft.setTextSize(1);
    tft.setTextColor(ST7735_YELLOW);
    tft.println("Humidity:");
    tft.println(" ");
    //SIM卡信号强度提示符
    tft.setCursor(4, 60);
    tft.setTextSize(1);
    tft.setTextColor(ST7735_YELLOW);
    tft.println("ASU:");
    tft.println(" ");
    
    //状态提示符
    tft.setCursor(4, 147);
    tft.setTextSize(1);
    tft.setTextColor(ST7735_CYAN);
    tft.println("Status:");
    tft.println(" ");
}
//x,y表示时间显示区域的起始坐标，字体size为1时，字体的高度为8，宽度为6
void LCD_update_Date(int x,int y,String date){
  //时间更新函数，比如year数值变化了就更新year所在的区域
  //date格式为“201203130423”
  if(date_year!=date.substring(0,4)){
      date_year = date.substring(0,4);
      tft.fillRect(x,y,24,8,ST7735_BLACK);
  }
  if(date_month!=date.substring(4,6)){
      date_month = date.substring(4,6);
      tft.fillRect(x+30,y,12,8,ST7735_BLACK);
  }
  if(date_day!=date.substring(6,8)){
      date_day = date.substring(6,8);
      tft.fillRect(x+48,y,12,8,ST7735_BLACK);
  }
  if(date_hour!=date.substring(8,10)){
      date_hour = date.substring(8,10);
      tft.fillRect(x+66,y,12,8,ST7735_BLACK);
  }
  if(date_minute!=date.substring(10,12)){
      date_minute = date.substring(10,12);
      tft.fillRect(x+84,y,12,8,ST7735_BLACK);
  }

  //显示时间
  tft.setCursor(x, y);
  tft.setTextSize(1);
  tft.setTextColor(ST7735_GREEN);
  tft.println(date_year+"-"+date_month+"-"+date_day+" "+date_hour+":"+date_minute);
  tft.println(" ");
}
//x,y表示温度显示区域的起始坐标，字体size为1时，字体的高度为8，宽度为6
void LCD_update_Temprature(int x,int y){
  tft.fillRect(x,y,42,8,ST7735_BLACK);
  tft.setCursor(x, y);
  tft.setTextSize(1);
  tft.setTextColor(ST7735_BLUE);
  //tft.println(temprature_00_00+tempratureS+" C");
  tft.print(temperature);
  tft.println(" C");
}
//x,y表示湿度显示区域的起始坐标，字体size为1时，字体的高度为8，宽度为6
void LCD_update_Humidity(int x,int y){
  //湿度更新函数
  //humidity格式为“25.12”
  tft.fillRect(x,y,48,8,ST7735_BLACK);
  tft.setCursor(x, y);
  tft.setTextSize(1);
  tft.setTextColor(ST7735_BLUE);
  //tft.println(humidityS+"RH%");
  tft.print(humidity);
  tft.println("RH%");
}
//x,y表示信号强度显示区域的起始坐标，字体size为1时，字体的高度为8，宽度为6
void LCD_update_ASU(int x,int y,String asu){
  //信号强度更新函数
  //asu格式为“15”
  
  tft.fillRect(x,y,12,8,ST7735_BLACK);
  
  tft.setCursor(x, y);
  tft.setTextSize(1);
  tft.setTextColor(ST7735_BLUE);
  tft.println(asu);
}
void showLocalDataOnLCD(){
  
  //if(st>10000){st=0;}
  LCD_update_Temprature(75,40);
  LCD_update_Humidity(75,50);

  //状态提示符
  tft.fillRect(50,147,60,8,ST7735_BLACK);
  tft.setCursor(50, 147);
  tft.setTextSize(1);
  tft.setTextColor(ST7735_BLUE);
  tft.println(st);  
}
void showRemoteDataOnLCD(){
  LCD_update_Date(18,28,uart_date);
  LCD_update_ASU(75,60,uart_asu);
}
void logs(String s){
  
    tft.fillRect(1,70,128,86,ST7735_BLACK);
    tft.setTextWrap(true);
    tft.setCursor(4, 70);
    tft.setTextSize(1);
    tft.setTextColor(ST7735_YELLOW);
    tft.println(s);
    tft.println(" ");

}

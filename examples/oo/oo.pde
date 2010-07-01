/*
  ad5206-controlled / sequencer
  
*/
#include "Led.h"
#include "Speedometer.h"
#include "Envelope.h"

#define DATAOUT 11//MOSI
#define DATAIN 12//MISO - not used, but part of builtin SPI
#define SPICLOCK  13//sck
#define SLAVESELECT 8//ss
#define SS 10 //fake slave select
#define CHANNEL_A 5
#define CHANNEL_B 4
#define CHANNEL_C 3
#define CHANNEL_D 1
#define CHANNEL_E 0
#define CHANNEL_F 2

// Pin bindings
const int LEDPIN = 5;
const int HALL_EFFECT_PIN = 0;
const int MEAN = 508;  // sensor at rest (no magnet)
const int SENSITIVITY = 40;  // sensor sensitivity
const unsigned long POLLING_INTERVAL = 1000;

// Other environmental constants
const unsigned int WHEEL_CIRCUM = 2100; // bike wheel circumference in mm (2100 = almost exact for 700-23c wheels)
// Initialize I/O Objects
Led led(LEDPIN);
Speedometer speedometer(HALL_EFFECT_PIN, WHEEL_CIRCUM, MEAN, SENSITIVITY, POLLING_INTERVAL);

int t = 0;

// int tempo = 100; // global sequencer tempo // replaced by tempo() function
int curTempo;
byte pot=0;
byte resistance=0;

unsigned long thisStep = millis();
unsigned long nextStep = millis() + curTempo;

int curSpeed;
const int maxSpeed = 25; //kpm
const int trackLength = 16;

int c;

int k[8] = {1, 255, 255, 255, 1, 255, 255, 255};

#define MAX 15

int trackBank[maxSpeed][trackLength];

int halfSteps[16] = {
  235,
222,
209,
198,
186,
176,
166,
157,
148,
140,
132,
125,
  0,
  0,
  0,
  0
  };  

int majorScale[16] = {
  235,

209,

186,
176,

157,

140,

125,
  118, //octave
  235,

209,

186,
176,

157,

140,

125,
  118 //octave
 
  };  

int rhythm[16] = {
  0,  //1 
  0, 
  0, 
  0,
  0, 
  0, 
  0, 
  0,  //8
  255,  
  255,
  255,
  255,
  255,
  255,
  255,
  255,  //16
  };  

int rhythm2[16] = {
  255,  //1 
  0, 
  255, 
  0,
  255, 
  0, 
  255, 
  0,  //8
  255,  
  0,
  255,
  0,
  255,
  0,
  255,
  0,  //16
  }; 
  
int rhythm3[16] = {
  255,  //1 
  255, 
  255, 
  255,
  255, 
  255, 
  255, 
  255,  //8
  255,  
  255,
  255,
  255,
  255,
  255,
  255,
  255,  //16
  };   
  
int duration[8] = {10, 10, 10, 1, 1, 10, 10, 10};
int pattern1[8] = {5, 10, 50, 10, 5, 77, 5, 10};
int pattern2[8] = {333, 111, 444, 999, 111, 777, 333, 522};


char spi_transfer(volatile char data)
{
  SPDR = data;                    // Start the transmission
  while (!(SPSR & (1<<SPIF)))     // Wait the end of the transmission
  {
  };
  return SPDR;                    // return the received byte
}

void controller_init() {
  byte i;
  byte clr;
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  pinMode(SLAVESELECT,OUTPUT);
  pinMode(SS, OUTPUT);
  digitalWrite(SLAVESELECT,HIGH); //disable device
  // SPCR = 01010000 
  //interrupt disabled,spi enabled,msb 1st,master,clk low when idle,
  //sample on leading edge of clk,system clock/4 (fastest)
  SPCR = (1<<SPE)|(1<<MSTR);
  clr=SPSR;
  clr=SPDR;
  delay(10);
  for (i=0;i<6;i++)
  {
    write_pot(i,255);
  }
}
  
void setup()   {                

  controller_init();
  
  Serial.begin(9600);
  changeTempo();
  
  // Serial.print("Note Generated!");
  write_pot(CHANNEL_A,0);
}

void loop()                     
{ 
  select_note();
  play_note();
  // Serial.println('done');
  //write_pot(CHANNEL_A,trackBank[speedometer.getSpeedKmph() - 1][t]);
  // write_pot(CHANNEL_B,rhythm3[t]);
  //  write_pot(CHANNEL_C,rhythm3[t]);
  // write_pot(CHANNEL_D,rhythm3[t]);
}

int note0[] = {180, 170, 160, 190, 200, 220, 230, 235 };
int note1[] = {100, 120, 130, 140, 150, 130, 140, 120 };
int note2[] = {20,  40,  80,  90,  120, 110, 70,  50 };
int *note;

void select_note() {
  int step = (micros() / 10000) % 3;
  switch (step) {
  case 0:
    note = note0;
    break;
  case 1:
    note = note1;
    break;
  case 2:
    note = note2;
    break;
  }
}


void play_note() {
  //sequencer_step();
  for(int i = 0; i < 8; i++) {
    long ms = micros();
    write_pot(CHANNEL_B, ( ms / 1500 ) % 255);
    write_pot(CHANNEL_C, *(note + i));
    // float diff = abs(sin(i));
    // diff = diff * (100 + diff);
    // Serial.print("[p: ");
    // Serial.print(halfSteps[i]);
    // Serial.print(" , ");
    // Serial.print("d: ");
    // Serial.print(diff);
    // Serial.print("]");
    // Serial.print("micros() valu: ");
    // Serial.print(ms);
    //   Serial.print("\tdelay valu: ");
    //   Serial.println(d);
    delay(1);
  }
}

void sequencer_step() {
  int curTime = millis(); 

  if (curTime > nextStep) {
    
    if(t<MAX) {
      t+=1;
    }
    else {
      changeTempo();
      t=0;
    }
	led.toggle();
    
    nextStep = curTime + curTempo; 
  }
}

byte write_pot(int address, int value)
{
  digitalWrite(SLAVESELECT,LOW);
  //2 byte opcode
  spi_transfer(address);
  spi_transfer(value);
  digitalWrite(SLAVESELECT,HIGH); //release chip, signal end transfer
}

void changeTempo() {
  curTempo = map(speedometer.getSpeedKmph(), 0, 33, 180, 20);
}



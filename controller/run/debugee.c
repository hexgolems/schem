#include <stdio.h>
#include <stdint.h>


int8_t   int8 = -100;
int16_t  int16 = -1000;
int32_t  int32 = -1000000;
int64_t  int64 = -1000000000;
uint8_t  uint8 = 0xff;
uint16_t uint16 = 0xffff;
uint32_t uint32 = 0xFFFFFFFF;
uint64_t uint64 = 0xFFFFFFFFFFFFFFFF;

int do_something(int arg1){
  printf("called do_something %d\n",arg1);
  return (int)uint32;
}

void some_loop(){
  int i = 0;
  for(i = 0; i<10; i++){
    printf("loop %d\n", i);
  }
}

int main(int argc, const char *argv[])
{
  do_something(int32);
  some_loop();
  return 0;
}

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>

pid_t server_pid;

void at_exit(){
  printf("exiting by killing %d\n",server_pid);
  kill(server_pid,SIGTERM);
  kill(server_pid,SIGKILL);
}

void sigfunc(int sig)
{
  printf("sig traped\n");
  at_exit();
  exit(0);
}


int main(int argc, const char *argv[])
{

  if(argc != 2){
    printf("usage: gdbsspawner EXECUTABLE\n");
    exit(0);
  }

  server_pid = fork();
  if(server_pid==0){
    printf("execing with pid %d\n",server_pid);
    setsid();
    execl("/usr/bin/gdbserver","gdbserver",":12345",argv[1], NULL);
  }else{
    printf("spawned with pid %d\n",server_pid);
    signal(SIGINT,sigfunc);
    signal(SIGTERM,sigfunc);
    int status;
    waitpid(server_pid,&status,0);
    printf("done\n");
  }
  return 0;
}

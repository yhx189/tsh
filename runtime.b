/***************************************************************************
 *  Title: Runtime environment 
 * -------------------------------------------------------------------------
 *    Purpose: Runs commands
 *    Author: Stefan Birrer
 *    Version: $Revision: 1.1 $
 *    Last Modification: $Date: 2005/10/13 05:24:59 $
 *    File: $RCSfile: runtime.c,v $
 *    Copyright: (C) 2002 by Stefan Birrer
 ***************************************************************************/
/***************************************************************************
 *  ChangeLog:
 * -------------------------------------------------------------------------
 *    $Log: runtime.c,v $
 *    Revision 1.1  2005/10/13 05:24:59  sbirrer
 *    - added the skeleton files
 *
 *    Revision 1.6  2002/10/24 21:32:47  sempi
 *    final release
 *
 *    Revision 1.5  2002/10/23 21:54:27  sempi
 *    beta release
 *
 *    Revision 1.4  2002/10/21 04:49:35  sempi
 *    minor correction
 *
 *    Revision 1.3  2002/10/21 04:47:05  sempi
 *    Milestone 2 beta
 *
 *    Revision 1.2  2002/10/15 20:37:26  sempi
 *    Comments updated
 *
 *    Revision 1.1  2002/10/15 20:20:56  sempi
 *    Milestone 1
 *
 ***************************************************************************/
#define __RUNTIME_IMPL__

/************System include***********************************************/
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>

/************Private include**********************************************/
#include "runtime.h"
#include "io.h"

/************Defines and Typedefs*****************************************/
/*  #defines and typedefs should have their names in all caps.
 *  Global variables begin with g. Global constants with k. Local
 *  variables should be in all lower case. When initializing
 *  structures and arrays, line everything up in neat columns.
 */

/************Global Variables*********************************************/

#define NBUILTINCOMMANDS (sizeof BuiltInCommands / sizeof(char*))

typedef struct bgjob_l {
  pid_t pid;
  char* job_status;
  int job_id; 
  struct bgjob_l* next;
  commandT* cmd;
} bgjobL;

char cmdline[100];         // cmdline to print
/* the pids of the background processes */
bgjobL *bgjobs = NULL;
bgjobL *bgjobc = NULL;                 // pointer to the current of bg job list

/* the pids of the foreground processes */
bgjobL *fgjobs = NULL;
bgjobL *fgjobc = NULL;                 // pointer to the current of fg job list

/* the head of Alias List */
AliasL *AliasH = NULL;

/* the pid of current foreground process */
int *fgpid = NULL;                     // store fgpid for ctrl+Z   

/************Function Prototypes******************************************/
/* run command */
static void RunCmdFork(commandT*, bool);
/* runs an external program command after some checks */
static void RunExternalCmd(commandT*, bool);
/* resolves the path and checks for exutable flag */
static bool ResolveExternalCmd(commandT*);
/* forks and runs a external program */
static void Exec(commandT*, bool);
/* runs a builtin command */
static void RunBuiltInCmd(commandT*);
/* checks whether a command is a builtin command */
static bool IsBuiltIn(char*);
/************External Declaration*****************************************/

/**************Implementation***********************************************/
int total_task;
void RunCmd(commandT** cmd, int n)
{
  int i;
  fgpid = malloc(sizeof(int)); 
  total_task = n;
  isAlias(cmd,n);
  if(n == 1)
    RunCmdFork(cmd[0], TRUE);
  else{
    RunCmdPipe(cmd[0], cmd[1]);
    for(i = 0; i < n; i++)
      ReleaseCmdT(&cmd[i]);
  }
}

void RunCmdFork(commandT* cmd, bool fork)
{
  if (cmd->argc<=0)
    return;
  if (IsBuiltIn(cmd->argv[0]))
  {
    RunBuiltInCmd(cmd);
  }
  else
  {
    RunExternalCmd(cmd, fork);
  }
}

void RunCmdBg(commandT* cmd)
{
  // TODO
}

void RunCmdPipe(commandT* cmd1, commandT* cmd2)
{
}

void RunCmdRedirOut(commandT* cmd, char* file)
{
}

void RunCmdRedirIn(commandT* cmd, char* file)
{
}


/*Try to run an external command*/
static void RunExternalCmd(commandT* cmd, bool fork)
{
  if (ResolveExternalCmd(cmd)){
    Exec(cmd, fork);
  }
  else {
    printf("%s: command not found\n", cmd->argv[0]);
    fflush(stdout);
    ReleaseCmdT(&cmd);
  }
}

/*Find the executable based on search list provided by environment variable PATH*/
static bool ResolveExternalCmd(commandT* cmd)
{
  char *pathlist, *c;
  char buf[1024];
  int i, j;
  struct stat fs;

  if(strchr(cmd->argv[0],'/') != NULL){
    if(stat(cmd->argv[0], &fs) >= 0){
      if(S_ISDIR(fs.st_mode) == 0)
        if(access(cmd->argv[0],X_OK) == 0){/*Whether it's an executable or the user has required permisson to run it*/
          cmd->name = strdup(cmd->argv[0]);
          return TRUE;
        }
    }
    return FALSE;
  }
  pathlist = getenv("PATH");
  if(pathlist == NULL) return FALSE;
  i = 0;
  while(i<strlen(pathlist)){
    c = strchr(&(pathlist[i]),':');
    if(c != NULL){
      for(j = 0; c != &(pathlist[i]); i++, j++)
        buf[j] = pathlist[i];
      i++;
    }
    else{
      for(j = 0; i < strlen(pathlist); i++, j++)
        buf[j] = pathlist[i];
    }
    buf[j] = '\0';
    strcat(buf, "/");
    strcat(buf,cmd->argv[0]);
    if(stat(buf, &fs) >= 0){
      if(S_ISDIR(fs.st_mode) == 0)
        if(access(buf,X_OK) == 0){/*Whether it's an executable or the user has required permisson to run it*/
          cmd->name = strdup(buf); 
          return TRUE;
        }
    }
  }
  return FALSE; /*The command is not found or the user don't have enough priority to run.*/
}

static void Exec(commandT* cmd, bool forceFork)
{  
  /* fork a child process */
  int pid = fork();
  int status; 
  
  /* child process */
  if (pid == 0)
    {
      /* put a job into background */
      if (cmd->bg == 1)
        {  
          setpgid(0,getpid());
	  execv(cmd->name,cmd->argv);
        }
      
      /* execute a job in foreground */
      else
        {
          setpgid(0,getpid());
          tcsetpgrp(STDIN_FILENO,getpid());
          execv(cmd->name,cmd->argv);
        }
    }
  else
    {
      /* add the job into bg job list */
      if (cmd->bg == 1)
      {  
        add_bg(pid,"Running",cmd);
      }
      /* add the job into fg job list and wait it */
      else 
      {
        add_fg(pid,"Running",cmd);
        tcsetpgrp(STDIN_FILENO,pid);
        kill(pid,SIGCONT);
        waitpid(pid,&status,WUNTRACED); 
        tcsetpgrp(STDIN_FILENO,getpgid(0));
        /* if the job ends delete it from fg job list*/
        if (status != 5247)
        {
          del_fg(fgjobc->job_id);
        }
        /* if the job is stopped by SIGTSTP add it to bg job list and delete it from fg job list */
        if (status == 5247)
        {
          char str_out[100];
          add_bg(pid,"Stopped",cmd);  
          if(!sprintf(str_out,"[%d]   %s                %s\n",bgjobc->job_id,bgjobc->job_status,get_cmd(bgjobc->cmd,1)))
            perror("Format Error!");
          del_fg(fgjobc->job_id);
          if(write(1,str_out,strlen(str_out)) == -1) perror("Write Error!");
        } 
      }
    }
}

static bool IsBuiltIn(char* cmd)
{
  if (strcmp(cmd,"cd") == 0 ) return TRUE;
  if (strcmp(cmd,"fg") == 0 ) return TRUE;
  if (strcmp(cmd,"bg") == 0 ) return TRUE;  
  if (strcmp(cmd,"jobs") == 0 ) return TRUE;
  if (strcmp(cmd,"alias") == 0) return TRUE;
  if (strcmp(cmd,"unalias") == 0) return TRUE;
  return FALSE;     
}


static void RunBuiltInCmd(commandT* cmd)
{
  if (strcmp(cmd->argv[0],"cd") == 0) 
  {
     if(cmd->argc == 1) 
      {
        if(chdir(getenv("HOME")) != 0) perror("Cannot change!\n");
      }
     else
      if(chdir(cmd->argv[1]) != 0) perror("Cannot change dir!\n");
  }
  if (strcmp(cmd->argv[0],"bg") == 0)
  {
    start_bg(cmd); 
  }
  if (strcmp(cmd->argv[0],"fg") == 0)
  {
    start_fg(cmd);
  }
  if (strcmp(cmd->argv[0],"jobs") == 0)
  {
    DisplayJobs();
  }
  if (strcmp(cmd->argv[0],"alias") == 0)
  {
    if(cmd->argc ==1)
      show_Alias();
    else
      add_Alias(cmd);
  }
  if (strcmp(cmd->argv[0],"unalias") == 0)
  {
    del_Alias(cmd->argv[1]);
  }

}
void CheckJobs()
{
  check_done();
}

/* Built-in command jobs implementation */
void DisplayJobs()
{
  bgjobL *p = bgjobs;          //temp pointer
  if(bgjobs == NULL) return;
  while (p != NULL)
  {
    char str_out[100];
    if(!sprintf(str_out,"[%d]   %s                %s\n",p->job_id,p->job_status,get_cmd(p->cmd,1)))
      perror("Format Error!");
    if(write(1,str_out,strlen(str_out)) == -1)
      perror("Write Error!");
    if (p->next == NULL)
      break;
    else
    {
      p = p->next;
    }
  }
}

/* Built-in command bg implementation */
void start_bg(commandT* cmd)
{
  bgjobL *p = bgjobc;
  if (bgjobc ==NULL)
    printf("-tsh: bg: current: no such job\n");
  else
    {
      /* bg without argument */
      if (cmd->argv[1] == NULL)
      {
        /* Send SIGCONT to current stopped bg job */
        if(strcmp(p->job_status, "Stopped") == 0)
        {
          kill(p->pid, SIGCONT);
          p->job_status = "Running"; 
        }
      }
      /* bg with argument job number */ 
      else
      {
        char* paras = cmd->argv[1];
        char c = paras[0];
        int id = c - 48;
        p = bgjobs;
        /* search the job and send SIGCONT to it*/
        while(p != NULL)
        {
          if( p->job_id == id )
          { 
            kill(p->pid, SIGCONT);
            p->job_status = "Running";
            p->cmd->bg = 1;
            break;
          }
          else
            if(p->next == NULL)
            {
              printf("-tsh: bg: %%%d: no such job\n",id);
              break;
            }
            else
            {
	      p = p->next; 
            }
        }
      }
    }
}

/* Built-in command fg implementation*/
void start_fg(commandT* cmd)
{
  bgjobL *p = bgjobc;
  if (bgjobc ==NULL)
    printf("-tsh: fg: current: no such job\n");
  else
    {
      int status;
      int pid;
      /* fg without argument */ 
      if (cmd->argv[1] == NULL)
      {
        add_fg(p->pid,"Running",p->cmd);
        /* set the job to foreground */
        tcsetpgrp(STDIN_FILENO,p->pid);
        kill(p->pid, SIGCONT);
       
        /* tsh wait for it to complete or stopped */
        waitpid(p->pid,&status,WUNTRACED);
        pid = p->pid;
        del_bg(p->job_id);
        
        /* if stopped add it to bg job list again */
        if (status == 5247)
        {
          fgjobc->cmd->bg = 0;
          add_bg(pid,"Stopped",fgjobc->cmd);
	  char str_out[100];
          if(!sprintf(str_out,"[%d]   %s                %s\n",bgjobc->job_id,bgjobc->job_status,get_cmd(bgjobc->cmd,1)))
            perror("Format Error!");
          if(write(1,str_out,strlen(str_out)) == -1)
            perror("Write Error!");
        } 
      }
      
      /* fg with argument job number */
      else
      {
        p = bgjobs;
        char* paras = cmd->argv[1];
        char c = paras[0];
        int id = c - 48;
        /* search the job send the job SIGCONT and set it to foreground*/ 
        while(p != NULL)
        {
          if( p->job_id  == id )
          { 
            add_fg(p->pid,"Running",p->cmd);
            /* set the job to foreground */
            tcsetpgrp(STDIN_FILENO,p->pid);
            kill(p->pid, SIGCONT);
           
            /* wait for it to exit or stop */
            waitpid(p->pid,&status,WUNTRACED);
            pid = p->pid;
            del_bg(id);
            
            /* if stopped add to bg job list again */
            if (status == 5247)
            {   
              fgjobc->cmd->bg = 0;
              add_bg(pid,"Stopped",fgjobc->cmd);
  	      char str_out[100];
              if(!sprintf(str_out,"[%d]   %s                %s\n",bgjobc->job_id,bgjobc->job_status,get_cmd(bgjobc->cmd,1)))
                perror("Format Error!");
              if(write(1,str_out,strlen(str_out)) == -1)
                perror("Write Error!");
            }
            break;
	  }
          else
            if(p->next == NULL)
            {
              printf("-tsh: fg: %%%d: no such job\n",id);
              break;
	    }
            else
            {
	      p = p->next; 
            }
        }
      } 
    }
}

/* Check the status of background jobs */
void check_done()
{
  bgjobL *p = bgjobs;          //temp pointer
  int done;
  if(bgjobs == NULL) return;
  while (p != NULL)
  {
    done = kill(p->pid,0);    // check process running or not
    if(done)        
      {
        char str_out[100];
        if(!sprintf(str_out,"[%d]   Done                   %s\n",p->job_id,get_cmd(p->cmd,0)))
          perror("Format Error!");
        if(write(1,str_out,strlen(str_out)) == -1)
          perror("Write Error!");
        del_bg(p->job_id);
      }
    if (p->next == NULL)
      break;
    else
    {
      p = p->next;
    }
  }
}

/* SIGTSTP handle function */
void hang_fg()
{
   if(fgjobc == NULL)
     return;
   else
     if(kill(fgjobc->pid,SIGTSTP))
       perror("ERROR");
}

/* SIGINT handle function */
void kill_fg()
{
  if(fgjobc == NULL)
     return;
  else
    {
      if(kill(fgjobc->pid,SIGINT))
      perror("ERROR");
    }
}

/* the functions below are used to process linked list and string their more specific description are in Runtime.h */
void add_bg(int pid, char *job_status, commandT* cmd)
{
  bgjobL *bgjobn;
  bgjobn = malloc(sizeof(bgjobL));
  bgjobn->pid = pid;
  bgjobn->job_status = job_status;
  bgjobn->cmd = cmd;
  bgjobn->next = NULL;
  if(bgjobc == NULL)
  {
    bgjobn->job_id = 1;
    bgjobs = bgjobn;
    bgjobc = bgjobn; 
  } 
  else
  {
    bgjobn->job_id = bgjobc->job_id + 1;
    bgjobc->next = bgjobn;
    bgjobc = bgjobn;
  }
}


void add_fg(int pid, char *job_status, commandT* cmd)
{
  bgjobL *fgjobn;
  fgjobn = malloc(sizeof(bgjobL));
  fgjobn->pid = pid;
  fgjobn->job_status = job_status;
  fgjobn->cmd = cmd;
  fgjobn->next = NULL;
  if(fgjobc == NULL)
  {
    fgjobn->job_id = 1;
    fgjobs = fgjobn;
    fgjobc = fgjobn; 
  } 
  else
  {
    fgjobn->job_id = fgjobc->job_id + 1;
    fgjobc->next = fgjobn;
    fgjobc = fgjobn;
  }
}

void del_bg(int job_id)
{
  bgjobL *p = bgjobs;
  bgjobL *q = bgjobs;
  while(p != NULL)
  {
    if(p->job_id == job_id)
    {
      if(p == bgjobs)
        {
          if(p->next == NULL)
            {
              del_bglist();
              break;
            }
          else
            {
              bgjobs = p->next;
              if(bgjobc == p) bgjobc = bgjobs;
              free(p);
              break;
            }
        }
      else
        {
          q->next = p->next;
          if(q->next == NULL) bgjobc = q;
          free(p);
          break;
        }  
    }
    else
    {
      q = p;
      p = p->next;
    }
  }
}

void del_fg(int job_id)
{
  bgjobL *p = fgjobs;
  bgjobL *q = fgjobs;
  while(p != NULL)
  {
    if(p->job_id == job_id)
    {
      if(p == fgjobs)
        {
          if(p->next == NULL)
            {
   	      del_fglist();
              break;
            }
          else
            {
              fgjobs = p->next;
              if(fgjobc == p) fgjobc = fgjobs;
              free(p);
              break;
            }
        }
      else
        {
          q->next = p->next;
          if(q->next == NULL) fgjobc = q;
          free(p);
          break;
        }  
    }
    else
    {
      q = p;
      p = p->next;
    }
  }
}

void del_bglist()
{
  bgjobL *p = bgjobs;
  bgjobL *q = bgjobs;
  bgjobc = NULL;
  bgjobs = NULL;
  while(p != NULL)
  {
    if(p->next ==NULL)
      {
        free(p);
        break;
      }
    else
      {
        p = p->next;
        free(q);
        q = p;
      }
  }
}

void del_fglist()
{
  bgjobL *p = fgjobs;
  bgjobL *q = fgjobs;
  fgjobc = NULL;
  fgjobs = NULL;
  while(p != NULL)
  {
    if(p->next ==NULL)
      {
        free(p);
        break;
      }
    else
      {
        p = p->next;
        free(q);
        q = p;
      }
  }
}

char* get_cmd(commandT* cmd,int flag)
{
   char* c = " ";  
   strcpy(cmdline,cmd->cmdline);
   int i = strlen(cmd->cmdline);
   if ((cmdline[i-1] - 34) == 0)
   {
     c = " ";
     strcat(cmdline,c);
   }
   if (cmd->bg == 1 && flag == 1)
   {
     c = "&";
     strcat(cmdline,c);
   }
   return cmdline;
}
void show_Alias()
{
  AliasL* p = AliasH; 
  while( p != NULL)
  {
    printf("alias %s\n", p->str);
    fflush(stdout);
    p = p->next;
  }
}
void del_Alias(char* name)
{
  AliasL *p = AliasH;
  AliasL *q = AliasH;
  while(p != NULL)
  {
    if(strcmp(p->name,name) == 0)
    {
      if(p == AliasH)
        {
          if(p->next == NULL)
            {
              del_Aliaslist();
              break;
            }
          else
            {
              AliasH = p->next;
              free(p);
              break;
            }
        }
      else
        {
          q->next = p->next;
          free(p);
          break;
        }  
    }
    else
    {
      q = p;
      p = p->next;
    }
  }
}
void del_Aliaslist()
{
  AliasL *p = AliasH;
  AliasL *q = AliasH;
  AliasH = NULL;
  while(p != NULL)
  {
    if(p->next ==NULL)
      {
        free(p);
        break;
      }
    else
      {
        p = p->next;
        free(q);
        q = p;
      }
  }
}

void add_Alias(commandT* cmd)
{
  AliasL* p = AliasH;
  AliasL* t = AliasH;
  if (p == NULL) 
   {
     p = malloc(sizeof(AliasL));
     p->next = NULL; 
     p->str = get_alias(cmd->cmdline);
     p->name = get_name(cmd->argv[1]);
     p->cmd_name = parse_wan(get_cmd_name(cmd->argv[1]));
     AliasH = p;
   }
  else
   {
     AliasL* q;
     q = malloc(sizeof(AliasL));
     q->str = get_alias(cmd->cmdline);
     q->name = get_name(cmd->argv[1]);
     q->cmd_name = parse_wan(get_cmd_name(cmd->argv[1]));
     while(p != NULL)
     {
       if (p->next != NULL)
         {
            if (strcmp(p->name,q->name) < 0)
            {
              t = p;
              p = p->next;
            } 
            else
            {
             
              t->next = q; 
              q->next = p;
            }
         }
       else
         {
           if(strcmp(p->name,q->name) < 0)
             {
               p->next = q;
               q->next = NULL;
               break;
             }
           else
             {
               if(p == AliasH)
                 {
                   q->next = p;
                   AliasH = q;
                   break;
                 }
               else
                 {
                   t->next = q;
                   q->next = p;
                   break;
                 }
             }
         }
     }
   }
}
void isAlias(commandT** cmd, int n)
{
  int i,j,count;
  int flag = 0;
  count = 1; 
  j = 0;
  commandT* cmd_n;
  cmd_n = malloc(sizeof(commandT) + sizeof(char*) * (count + 2));
  for (i = 0; i < n; i++)
  {
    if (strcmp(cmd[i]->argv[0], "unalias") == 0)
      continue;
    for (j = 0; j< cmd[i]->argc; j++)
    {
      AliasL* p = AliasH;
      while(p != NULL)
      {
        if (strcmp(p->name, cmd[i]->argv[j]) == 0)
        {
          cmd_n->argv[j] = get_exec(p->cmd_name);
          count = count + 1;
          flag = 1;
          p = p->next;
        }
        else
        {
         // cmd_n->argv[j] = cmd[i]->argv[j];
          count = count + 1;
          p = p ->next;
        }
      }
    }
    if(flag)
    {
      cmd_n->name = cmd_n->argv[0];
      cmd_n->redirect_in = cmd[i]->redirect_in;
      cmd_n->redirect_out = cmd[i]->redirect_out;
      cmd_n->is_redirect_in = cmd[i]->is_redirect_in;
      cmd_n->is_redirect_out = cmd[i]->is_redirect_out;
      cmd_n->bg = cmd[i]->bg;
      cmd_n->argc = count;
      cmd_n->argv[cmd_n->argc] = NULL;
      cmd[i] = cmd_n;
    }
  }
}


char* get_name(char* str)
{
  int i = 0;
  while(str[i] != '=')
    i = i + 1;
  int j;
  char s[50];
  for (j = 0; j < i; j++)
  {
    s[j] = str[j];
  }
  s[i] = '\0';
  char* name = malloc(sizeof(char) * (strlen(s) + 1));
  for(i = 0;i <= strlen(s); i++)
    name[i] = s[i];
  return name; 
}
char* get_cmd_name(char* str)
{
  int i = 0;
  while(str[i] != '=')
    i = i + 1;
  int j;
  char s[50];
  j = i + 2;
  i = 0;
  if (str[strlen(str)] == '\'')
    {
      for (; j < (strlen(str) - 1); j++)
      {
        s[i] = str[j];
        i = i + 1;
      }
    }
  else
    {
      for (; j < strlen(str); j++)
      {
        s[i] = str[j];
        i = i + 1;
      }
    } 
  s[i] = '\0';
  char* name = malloc(sizeof(char) * (strlen(s) + 1));
  for(i = 0;i <= strlen(s); i++)
    name[i] = s[i];
  return name;
}
char* get_alias(char* str)
{
  int i = 0;
  while(str[i] != ' ')
    i = i + 1;
  int j;
  char s[50];
  j = i + 1;
  i = 0;
  for (; j < strlen(str); j++)
  {
    s[i] = str[j];
    i = i + 1;
  }  
  s[i] = '\0';
  char* name = malloc(sizeof(char) * (strlen(s) + 1));
  for(i = 0;i <= strlen(s); i++)
    name[i] = s[i];
  return name;
}
char* get_exec(char* str)
{
  int i = 0;
  while(str[i] != ' ')
    {
      i = i + 1;
      if(str[i] == '\0')
        break;
    }
  int j;
  char s[50];
  for (j = 0; j < i; j++)
  {
    s[j] = str[j];
  }
  if(str[i] == ' ')
  {
    s[i] = str[i];
    s[i+1] = '\0';
  }
  else
  {
    s[i] = '\0';
  }
  char* name = malloc(sizeof(char) * (strlen(s) + 1));
  for(i = 0;i <= strlen(s); i++)
    name[i] = s[i];
  return name; 
}
commandT* CreateCmdT(int n)
{
  int i;
  commandT * cd = malloc(sizeof(commandT) + sizeof(char *) * (n + 1));
  cd -> name = NULL;
  cd -> cmdline = NULL;
  cd -> is_redirect_in = cd -> is_redirect_out = 0;
  cd -> redirect_in = cd -> redirect_out = NULL;
  cd -> argc = n;
  for(i = 0; i <=n; i++)
    cd -> argv[i] = NULL;
  return cd;
}
char* parse_wan(char* input)
{
  int i = 0;
  int j = 0;
  int flag = 0;
  while(input[i] != '~')
    {
      i = i + 1;
      if(input[i] == '\0')
        {
          flag = 1;
          break;
        }
    }
  if (flag == 1) return input;
  char* name = malloc(sizeof(char) *(strlen(getenv("HOME")) + strlen(input)));
  for(j = 0; j < i; j++)
  {
    name[j] = input[j];
  }
  char* s = getenv("HOME");
  for(j = i; j< (strlen(getenv("HOME")) + i); j++)
  {
    name[j] = s[j - i];
  }
  for(; j< (strlen(getenv("HOME")) + strlen(input)); j++)
  {
    if(input[i + 1] == '\'') break;
    name[j] = input[i + 1];
    i = i + 1;
  }
  return name;
}
/*Release and collect the space of a commandT struct*/
void ReleaseCmdT(commandT **cmd){
  int i;
  if((*cmd)->name != NULL) free((*cmd)->name);
  if((*cmd)->cmdline != NULL) free((*cmd)->cmdline);
  if((*cmd)->redirect_in != NULL) free((*cmd)->redirect_in);
  if((*cmd)->redirect_out != NULL) free((*cmd)->redirect_out);
  for(i = 0; i < (*cmd)->argc; i++)
    if((*cmd)->argv[i] != NULL) free((*cmd)->argv[i]);
  free(*cmd);
}

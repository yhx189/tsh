/***************************************************************************
 *  Title: Runtime environment 
 * -------------------------------------------------------------------------
 *    Purpose: Runs commands
 *    Author: Stefan Birrer
 *    Version: $Revision: 1.1 $
 *    Last Modification: $Date: 2005/10/13 05:24:59 $
 *    File: $RCSfile: runtime.h,v $
 *    Copyright: (C) 2002 by Stefan Birrer
 ***************************************************************************/
/***************************************************************************
 *  ChangeLog:
 * -------------------------------------------------------------------------
 *    $Log: runtime.h,v $
 *    Revision 1.1  2005/10/13 05:24:59  sbirrer
 *    - added the skeleton files
 *
 *    Revision 1.3  2002/10/23 21:54:27  sempi
 *    beta release
 *
 *    Revision 1.2  2002/10/21 04:47:05  sempi
 *    Milestone 2 beta
 *
 *    Revision 1.1  2002/10/15 20:20:56  sempi
 *    Milestone 1
 *
 ***************************************************************************/

#ifndef __RUNTIME_H__
#define __RUNTIME_H__

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

/************System include***********************************************/

/************Private include**********************************************/

/************Defines and Typedefs*****************************************/
/*  #defines and typedefs should have their names in all caps.
 *  Global variables begin with g. Global constants with k. Local
 *  variables should be in all lower case. When initializing
 *  structures and arrays, line everything up in neat columns.
 */

#undef EXTERN
#ifdef __RUNTIME_IMPL__
#define EXTERN
#define VAREXTERN(x, y) x = y;
#else
#define EXTERN extern
#define VAREXTERN(x, y) extern x;
#endif

typedef struct command_t
{
  char* name;
  char *cmdline;
  char *redirect_in, *redirect_out;
  int input_fd, output_fd;
  int is_redirect_in, is_redirect_out;
  int bg;
  int argc;
  char* argv[];
} commandT;

typedef struct Alias_L{
  char* name;
  char* cmd_name;
  char* str;
  struct Alias_L* next;
}AliasL;

/************Global Variables*********************************************/

/***********************************************************************
 *  Title: Force a program exit 
 * ---------------------------------------------------------------------
 *    Purpose: Signals that a program exit is required
 ***********************************************************************/
VAREXTERN(bool forceExit, FALSE);

/************Function Prototypes******************************************/

/***********************************************************************
 *  Title: Runs a command 
 * ---------------------------------------------------------------------
 *    Purpose: Runs a command.
 *    Input: a command structure
 *    Output: void
 ***********************************************************************/
EXTERN void RunCmd(commandT**,int);

/***********************************************************************
 *  Title: Runs a command in background
 * ---------------------------------------------------------------------
 *    Purpose: Runs a command in background.
 *    Input: a command structure
 *    Output: void
 ***********************************************************************/
EXTERN void RunCmdBg(commandT*);

/***********************************************************************
 *  Title: Runs two command with a pipe
 * ---------------------------------------------------------------------
 *    Purpose: Runs two command connected with a pipe.
 *    Input: two command structure
 *    Output: void
 ***********************************************************************/
EXTERN void RunCmdPipe(commandT**, int n);

/***********************************************************************
 *  Title: Runs two command with output redirection
 * ---------------------------------------------------------------------
 *    Purpose: Runs a command and redirects the output to a file.
 *    Input: a command structure structure and a file name
 *    Output: void
 ***********************************************************************/
EXTERN void RunCmdRedirOut(commandT*, char*);

/***********************************************************************
 *  Title: Runs two command with input redirection
 * ---------------------------------------------------------------------
 *    Purpose: Runs a command and redirects the input to a file.
 *    Input: a command structure structure and a file name
 *    Output: void
 ***********************************************************************/
EXTERN void RunCmdRedirIn(commandT*, char*);

/***********************************************************************
 *  Title: Stop the foreground process
 * ---------------------------------------------------------------------
 *    Purpose: Stops the current foreground process if there is any.
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void StopFgProc();

/***********************************************************************
 *  Title: Create a command structure 
 * ---------------------------------------------------------------------
 *    Purpose: Creates a command structure.
 *    Input: the number of arguments
 *    Output: the command structure
 ***********************************************************************/
EXTERN commandT* CreateCmdT(int);

/***********************************************************************
 *  Title: Release a command structure 
 * ---------------------------------------------------------------------
 *    Purpose: Frees the allocated memory of a command structure.
 *    Input: the command structure
 *    Output: void
 ***********************************************************************/
EXTERN void ReleaseCmdT(commandT**);

/***********************************************************************
 *  Title: Get the current working directory 
 * ---------------------------------------------------------------------
 *    Purpose: Gets the current working directory.
 *    Input: void
 *    Output: a string containing the current working directory
 ***********************************************************************/
EXTERN char* getCurrentWorkingDir();

/***********************************************************************
 *  Title: Get user name 
 * ---------------------------------------------------------------------
 *    Purpose: Gets user name logged in on the controlling terminal.
 *    Input: void
 *    Output: a string containing the user name
 ***********************************************************************/
EXTERN char* getLogin();

/***********************************************************************
 *  Title: Check the jobs 
 * ---------------------------------------------------------------------
 *    Purpose: Checks the status of the background jobs.
 *    Input: void
 *    Output: void 
 ***********************************************************************/
EXTERN void CheckJobs();

/************************************************************************
 *  Title: Start jobs in background
 * ---------------------------------------------------------------------
 *    Purpose: To start a process which is hanging in background
 *    Input: the command structure
 *    Output: void
 ***********************************************************************/
EXTERN void start_bg(commandT*);

/************************************************************************
 *  Title: Start jobs in foreground
 * ---------------------------------------------------------------------
 *    Purpose: To start a process which is hanging in foreground
 *    Input: the command structure
 *    Output: void
 ***********************************************************************/
EXTERN void start_fg(commandT*);

/************************************************************************
 *  Title: get command
 * ---------------------------------------------------------------------
 *    Purpose: To get commandline from a command structure
 *    Input: the command structure, int flag
 *    Output: void
 ***********************************************************************/
EXTERN char* get_cmd(commandT* cmd, int flag);

/************************************************************************
 *  Title: Display jobs
 * ---------------------------------------------------------------------
 *    Purpose: To display background jobs in the terminal
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void DisplayJobs();

/************************************************************************
 *  Title: Hang fg jobs to bg
 * ---------------------------------------------------------------------
 *    Purpose: To hang up foreground jobs in the background
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void hang_fg();

/************************************************************************
 *  Title: add bg job
 * ---------------------------------------------------------------------
 *    Purpose: To add bg jobs to the bgjob list
 *    Input: int processid, char* process status, bg job struct current 
 *    Output: void
 ***********************************************************************/
EXTERN void add_bg(int pid, char *job_status, commandT* cmd);

/************************************************************************
 *  Title: delete bg job
 * ---------------------------------------------------------------------
 *    Purpose: To delete bg jobs from the bgjob list
 *    Input: int job id
 *    Output: void
 ***********************************************************************/
EXTERN void del_bg(int job_id);

/************************************************************************
 *  Title: delete bg job list
 * ---------------------------------------------------------------------
 *    Purpose: To delete the bg job list and free the memory
 *    Input: void 
 *    Output: void
 ***********************************************************************/
EXTERN void del_bglist();

/************************************************************************
 *  Title: check done bg job
 * ---------------------------------------------------------------------
 *    Purpose: To check done bg job in the list
 *    Input: void 
 *    Output: void
 ***********************************************************************/
EXTERN void check_done();

/************************************************************************
 *  Title: kill foreground job
 * ---------------------------------------------------------------------
 *    Purpose: To kill foreground jobs
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void kill_fg();

/************************************************************************
 *  Title: add foreground job
 * ---------------------------------------------------------------------
 *    Purpose: To add foreground job to foreground job list
 *    Input: int process id, char* job status, the command structure 
 *    Output: void
 ***********************************************************************/
EXTERN void add_fg(int pid, char *job_status, commandT* cmd);

/************************************************************************
 *  Title: delete foreground job
 * ---------------------------------------------------------------------
 *    Purpose: To delete foreground job from foreground job list
 *    Input: int job id
 *    Output: void
 ***********************************************************************/
EXTERN void del_fg(int job_id);

/************************************************************************
 *  Title: delete foreground job list
 * ---------------------------------------------------------------------
 *    Purpose: To delete foreground job list and free the memory
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void del_fglist();

/************************************************************************
 *  Title: show alias
 * ---------------------------------------------------------------------
 *    Purpose: To show exist aliases
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void show_Alias();

/************************************************************************
 *  Title: delete alias
 * ---------------------------------------------------------------------
 *    Purpose: To delete alias from the alias list
 *    Input: char* name of alias
 *    Output: void
 ***********************************************************************/
EXTERN void del_Alias(char* name);

/************************************************************************
 *  Title: add alias
 * ---------------------------------------------------------------------
 *    Purpose: To add an alias to alias list
 *    Input: the command structure
 *    Output: void
 ***********************************************************************/
EXTERN void add_Alias(commandT* cmd);

/************************************************************************
 *  Title: is Alias
 * ---------------------------------------------------------------------
 *    Purpose: To judge the command contains alias or not
 *    Input: the array of command structure
 *    Output: void
 ***********************************************************************/
EXTERN void isAlias(commandT** cmd, int n);

/************************************************************************
 *  Title: get name
 * ---------------------------------------------------------------------
 *    Purpose: To get name of an alias 
 *    Input: char* str
 *    Output: char*
 ***********************************************************************/
EXTERN char* get_name(char* str);

/************************************************************************
 *  Title: get alias
 * ---------------------------------------------------------------------
 *    Purpose: To get the entire alias command line
 *    Input: char* str
 *    Output: char*
 ***********************************************************************/
EXTERN char* get_alias(char* str);

/************************************************************************
 *  Title: get command name
 * ---------------------------------------------------------------------
 *    Purpose: To get the command name of an alias 
 *    Input: char* str
 *    Output: char*
 ***********************************************************************/
EXTERN char* get_cmd_name(char* str);

/************************************************************************
 *  Title: get execute
 * ---------------------------------------------------------------------
 *    Purpose: To get the command to be excecute from an alias 
 *    Input: char* str
 *    Output: char*
 ***********************************************************************/
EXTERN char* get_exec(char* str);

/************************************************************************
 *  Title: delete alias list
 * ---------------------------------------------------------------------
 *    Purpose: To delete the alias list an free the memory 
 *    Input: void
 *    Output: void
 ***********************************************************************/
EXTERN void del_Aliaslist();

/************************************************************************
 *  Title: parse ~
 * ---------------------------------------------------------------------
 *    Purpose: To substitude ~ in the command
 *    Input: char* input
 *    Output: char* 
 ***********************************************************************/
EXTERN char* parse_wan(char* input);

/************External Declaration*****************************************/

/**************Definition***************************************************/
#endif /* __RUNTIME_H__ */

/******************************************************************************/
/*                                                                            */
/*     CONV (converter) for Agrif (Adaptive Grid Refinement In Fortran)       */
/*                                                                            */
/* Copyright or   or Copr. Laurent Debreu (Laurent.Debreu@imag.fr)            */
/*                        Cyril Mazauric (Cyril_Mazauric@yahoo.fr)            */
/* This software is governed by the CeCILL-C license under French law and     */
/* abiding by the rules of distribution of free software.  You can  use,      */
/* modify and/ or redistribute the software under the terms of the CeCILL-C   */
/* license as circulated by CEA, CNRS and INRIA at the following URL          */
/* "http://www.cecill.info".                                                  */
/*                                                                            */
/* As a counterpart to the access to the source code and  rights to copy,     */
/* modify and redistribute granted by the license, users are provided only    */
/* with a limited warranty  and the software's author,  the holder of the     */
/* economic rights,  and the successive licensors  have only  limited         */
/* liability.                                                                 */
/*                                                                            */
/* In this respect, the user's attention is drawn to the risks associated     */
/* with loading,  using,  modifying and/or developing or reproducing the      */
/* software by the user in light of its specific status of free software,     */
/* that may mean  that it is complicated to manipulate,  and  that  also      */
/* therefore means  that it is reserved for developers  and  experienced      */
/* professionals having in-depth computer knowledge. Users are therefore      */
/* encouraged to load and test the software's suitability as regards their    */
/* requirements in conditions enabling the security of their systems and/or   */
/* data to be ensured and,  more generally, to use and operate it in the      */
/* same conditions as regards security.                                       */
/*                                                                            */
/* The fact that you are presently reading this means that you have had       */
/* knowledge of the CeCILL-C license and that you accept its terms.           */
/******************************************************************************/
/* version 1.7                                                                */
/******************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "decl.h"


/******************************************************************************/
/*                            associate                                       */
/******************************************************************************/
/* This subroutine is used to open a file                                     */
/******************************************************************************/
FILE * associate (char *filename)
{
  char filefich[LONG_C];
  sprintf(filefich,"%s/%s",nomdir,filename);
  return fopen (filefich, "w");
}


/******************************************************************************/
/*                          associateaplus                                    */
/******************************************************************************/
/* This subroutine is used to open a file with option a+                      */
/******************************************************************************/
FILE * associateaplus (char *filename)
{
  char filefich[LONG_C];
  sprintf(filefich,"%s/%s",nomdir,filename);
  return fopen (filefich, "a+");
}


/******************************************************************************/
/*                           setposcurname                                       */
/******************************************************************************/
/* This subroutine is used to know the current position in the file in argument    */
/******************************************************************************/
/*                                                                            */
/*                      setposcur ---------> position in file                 */
/*                                                                            */
/******************************************************************************/
long int setposcurname(FILE *fileout)
{
   fflush(fileout);
   return ftell(fileout);
}

/******************************************************************************/
/*                           setposcur                                        */
/******************************************************************************/
/* This subroutine is used to know the current position in the file           */
/******************************************************************************/
/*                                                                            */
/*                      setposcur ---------> position in file                 */
/*                                                                            */
/******************************************************************************/
long int setposcur()
{
   fflush(fortranout);
   return ftell(fortranout);
}

/******************************************************************************/
/*                      setposcurinoldfortranout                              */
/******************************************************************************/
/* This subroutine is used to know the position in the oldfortranout         */
/******************************************************************************/
/*                                                                            */
/*             setposcurinoldfortranout ---------> position in file           */
/*                                                                            */
/******************************************************************************/
long int setposcurinoldfortranout()
{
   fflush(oldfortranout);
   return ftell(oldfortranout);
}

/******************************************************************************/
/*                         copyuse_0                                          */
/******************************************************************************/
/* Firstpass 0                                                                */
/* We should write in the fortranout the USE tok_name                         */
/* read in the original file                                                  */
/******************************************************************************/
/*                                                                            */
/******************************************************************************/
void copyuse_0(char *namemodule)
{
   if (firstpass == 0 && IsTabvarsUseInArgument_0() == 1 )
   {
      /* We should write this declaration into the original subroutine too    */
      fprintf(oldfortranout,"      USE %s \n",namemodule);
   }
}

/******************************************************************************/
/*                         copyuseonly_0                                      */
/******************************************************************************/
/* Firstpass 0                                                                */
/* We should write in the fortranout the USE tok_name, only                   */
/* read in the original file                                                  */
/******************************************************************************/
/*                                                                            */
/******************************************************************************/
void copyuseonly_0(char *namemodule)
{
   if (firstpass == 0 && IsTabvarsUseInArgument_0() == 1 )
   {
      /* We should write this declaration into the original subroutine too    */
      fprintf(oldfortranout,"      USE %s , ONLY : \n",namemodule);
   }
}

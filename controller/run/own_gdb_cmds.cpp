/*BEGIN_LEGAL
Intel Open Source License

Copyright (c) 2002-2012 Intel Corporation. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.  Redistributions
in binary form must reproduce the above copyright notice, this list of
conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.  Neither the name of
the Intel Corporation nor the names of its contributors may be used to
endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE INTEL OR
ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
END_LEGAL */
/*
 * This is an example tool that adds extended debugger commands.  See the
 * Pin User Manual section "Debugging the Application while Running Under Pin"
 * for a tutorial about this tool.
 *
 * This tool adds extended commands to the debugger that allow you to set
 * breakpoints which trigger when the application's stack usage crosses a
 * user-specified threshold.  It also keeps track of stack usage statistics,
 * which can be displayed from within the debugger.  In GDB, type "monitor help"
 * to show a list of the commands this tool adds.
 */

#include <iostream>
#include <sstream>
#include <fstream>
#include <string>
#include <cctype>
#include <map>
#include "pin.H"


// Command line switches for this tool.
//
KNOB<std::string> KnobOut(KNOB_MODE_WRITEONCE, "pintool",
    "o", "",
    "When using -stackbreak, debugger connection information is printed to this file (default stderr)");
KNOB<UINT32> KnobTimeout(KNOB_MODE_WRITEONCE, "pintool",
    "timeout", "0",
    "When using -stackbreak, wait for this many seconds for debugger to connect (zero means wait forever)");


// Virtual register we use to point to each thread's TINFO structure.
//
static REG RegTinfo;


// Information about each thread.
//
struct TINFO
{
    TINFO(ADDRINT base) : _stackBase(base), _max(0), _maxReported(0) {}

    ADDRINT _stackBase;     // Base (highest address) of stack.
    size_t _max;            // Maximum stack usage so far.
    size_t _maxReported;    // Maximum stack usage reported at breakpoint.
    std::ostringstream _os; // Used to format messages.
};

typedef std::map<THREADID, TINFO *> TINFO_MAP;
static TINFO_MAP ThreadInfos;

static std::ostream *Output = &std::cerr;
static VOID OnThreadStart(THREADID, CONTEXT *, INT32, VOID *);
static VOID OnThreadEnd(THREADID, const CONTEXT *, INT32, VOID *);
static BOOL DebugInterpreter(THREADID, CONTEXT *, const string &, string *, VOID *);
static std::string TrimWhitespace(const std::string &);


/* ===================================================================== */
/* Print Help Message                                                    */
/* ===================================================================== */

INT32 Usage()
{
    cerr << "This tool demonstrates the use of extended debugger commands" << endl;
    cerr << endl << KNOB_BASE::StringKnobSummary() << endl;
    return -1;
}

/* ===================================================================== */
/* Main                                                                  */
/* ===================================================================== */

int main(int argc, char *argv[])
{
    if (PIN_Init(argc, argv)) return Usage();

    if (PIN_GetDebugStatus() == DEBUG_STATUS_DISABLED)
    {
        std::cerr << "Application level debugging must be enabled to use this tool.\n";
        std::cerr << "Start Pin with either -appdebug or -appdebug_enable.\n";
        std::cerr << std::flush;
        return 1;
    }

    if (!KnobOut.Value().empty())
        Output = new std::ofstream(KnobOut.Value().c_str());

    // Allocate a virtual register that each thread uses to point to its
    // TINFO data.  Threads can use this virtual register to quickly access
    // their own thread-private data.
    //
    RegTinfo = PIN_ClaimToolRegister();
    if (!REG_valid(RegTinfo))
    {
        std::cerr << "Cannot allocate a scratch register.\n";
        std::cerr << std::flush;
        return 1;
    }
    PIN_AddDebugInterpreter(DebugInterpreter, 0);
    PIN_AddThreadStartFunction(OnThreadStart, 0);
    PIN_AddThreadFiniFunction(OnThreadEnd, 0);

    PIN_StartProgram();
    return 0;
}


/*
 * This call-back implements the extended debugger commands.
 *
 *  tid[in]         Pin thread ID for debugger's "focus" thread.
 *  ctxt[in,out]    Register state for the debugger's "focus" thread.
 *  cmd[in]         Text of the extended command.
 *  result[out]     Text that the debugger prints when the command finishes.
 *
 * Returns: TRUE if we recognize this extended command.
 */
static BOOL DebugInterpreter(THREADID tid, CONTEXT *ctxt, const string &cmd, string *result, VOID *)
{
    TINFO_MAP::iterator it = ThreadInfos.find(tid);
    if (it == ThreadInfos.end())
        return FALSE;
    TINFO *tinfo = it->second;

    std::string line = TrimWhitespace(cmd);
    *result = "";

    if (line == "help")
    {
        result->append("mappings             -- Mappings.\n");
        return TRUE;
    }
    else if(line == "mappings")
    {
      tinfo->_os.str("");
      tinfo->_os << "{"; //open JSON
      for( IMG img= APP_ImgHead(); IMG_Valid(img); img = IMG_Next(img) )
      {
        const string& name = LEVEL_PINCLIENT::IMG_Name(img);
        tinfo->_os <<"\""<< name << "\":{"; //open img
        ADDRINT address = LEVEL_PINCLIENT::IMG_LowAddress(img);
        tinfo->_os << "\"start\":" << address << ",";
        address = LEVEL_PINCLIENT::IMG_HighAddress(img);
        tinfo->_os << "\"end\":" << address << ",";
        tinfo->_os << "\"sections\":" << "{"; //open sections
        for( SEC sec = IMG_SecHead(img); SEC_Valid(sec); sec = SEC_Next(sec))
        {
          const string& name = LEVEL_PINCLIENT::SEC_Name(sec);
          if(name != "")
          {
            tinfo->_os << "\"" << name <<"\":{"; //open section
            ADDRINT address = LEVEL_PINCLIENT::SEC_Address(sec);
            tinfo->_os << "\"start\":" << address << ",";
            USIZE size = LEVEL_PINCLIENT::SEC_Size(sec);
            if(SEC_Valid(SEC_Next(sec)))
            {
              tinfo->_os << "\"size\":" << size << "},"; //close section
            }else
            {
              tinfo->_os << "\"size\":" << size << "}}"; //close section and sections
            }
          }
        }
        if(IMG_Valid(IMG_Next(img)))
        {
          tinfo->_os << "},"; //close img
        }else
        {
          tinfo->_os << "}}"; //close img and json
        }
      }
      *result = tinfo->_os.str();
      return TRUE;
    }

    return FALSE;   /* Unknown command */
}


static VOID OnThreadStart(THREADID tid, CONTEXT *ctxt, INT32, VOID *)
{
    TINFO *tinfo = new TINFO(PIN_GetContextReg(ctxt, REG_STACK_PTR));
    ThreadInfos.insert(std::make_pair(tid, tinfo));
    PIN_SetContextReg(ctxt, RegTinfo, reinterpret_cast<ADDRINT>(tinfo));
}

static VOID OnThreadEnd(THREADID tid, const CONTEXT *ctxt, INT32, VOID *)
{
    TINFO_MAP::iterator it = ThreadInfos.find(tid);
    if (it != ThreadInfos.end())
    {
        delete it->second;
        ThreadInfos.erase(it);
    }
}

/*
 * Trim whitespace from a line of text.  Leading and trailing whitespace is removed.
 * Any internal whitespace is replaced with a single space (' ') character.
 *
 *  inLine[in]  Input text line.
 *
 * Returns: A string with the whitespace trimmed.
 */
static std::string TrimWhitespace(const std::string &inLine)
{
    std::string outLine = inLine;

    bool skipNextSpace = true;
    for (std::string::iterator it = outLine.begin();  it != outLine.end();  ++it)
    {
        if (std::isspace(*it))
        {
            if (skipNextSpace)
            {
                it = outLine.erase(it);
                if (it == outLine.end())
                    break;
            }
            else
            {
                *it = ' ';
                skipNextSpace = true;
            }
        }
        else
        {
            skipNextSpace = false;
        }
    }
    if (!outLine.empty())
    {
        std::string::reverse_iterator it = outLine.rbegin();
        if (std::isspace(*it))
            outLine.erase(outLine.size()-1);
    }
    return outLine;
}

/*
--  Panteleev Sergey 2017
--
--  Maxscript. Show calltips in 3dsmax mxseditor
--
*/

(
----------------------- Struct that handles HotKey events and custom maxscript execution by a shortcut while in mxseditor --------------------------------------
struct mxseHotKeyOps (

	public 
		
	dll,
	hwnd,
	hotkeys,
	messagesnooper,
	sendmsg,
	lastmousemove = 0,
	dwellDelay = 666,
	dwellActive = false,
	dwellCallback,
	hotkey_callbacks = #(),
	
	fn msgEvent m = (
		
		if m.msg == 786 do ::mxse.handleEvent m.wparam  -- 0x0312: ("WM_HOTKEY");		
-- 		if m.msg == 0x0203 do format "Doubleclick!!\n" 
		
		/*
		----------------------- HANDLING DWELL EVENTS ------------------------------------------------------------
		if m.msg == 0x0200 do (
		
			::mxse.lastmousemove = timestamp()
			::mxse.dwellActive = false
		)
		
		-- WM_TIMER handler
		if m.msg == 0x113 do (
			
			t = timestamp()
			if ( t - ::mxse.lastmousemove ) > ::mxse.dwellDelay and not ::mxse.dwellActive do (
				
				::mxse.dwellActive = true 
				
				if ::mxse.dwellCallback != undefined do (
					
					::mxse.dwellCallback()
					
				)

			)
			
		)*/
		--------------------------------------------------------------------------------------------------------------------------
	),
	
	fn handleEvent index = (
		
		if classof hotkey_callbacks[ index ] == MAXScriptFunction do hotkey_callbacks[ index ]()
		true
	),
	
	fn mxsEditorHWND asdotnet:true = (
	
		for c in (windows.getchildrenhwnd 0) where c[4] == "MXS_SciTEWindow" do for t in (windows.getchildrenhwnd c[1]) where t[4] == "MXS_Scintilla" do (
		
			if asdotnet then return dotNetObject "system.intptr" t[1] else return t[1]
		
		)
		
	),

	fn registerHotKey keyCode callbackFn alt:off ctrl:on shift:off = (
			
		hwnd = mxsEditorHWND()
		index = 1 + hotkey_callbacks.count
				
		_alt   = if alt   then 0x0001 else 0x0000
		_ctrl  = if ctrl  then 0x0002 else 0x0000
		_shift = if shift then 0x0004 else 0x0000
		
		modifiers = bit.or (bit.or _alt _ctrl) _shift
		
		if classof callbackFn == MAXScriptFunction do (
			
			regResult = hotkeys.RegisterHotKey hwnd index modifiers keyCode
			append hotkey_callbacks callbackFn
			
		)

		if index == 1 do (
			
			messagesnooper.assignHandle hwnd			
			dotnet.addEventHandler messagesnooper "MessageEvent" msgEvent
			
		)
		
	),
	
	fn unregisterHotKeys = (
			
		hwnd = mxsEditorHWND()
		messagesnooper.releaseHandle()
		
		for i = hotkey_callbacks.count to 1 by -1 do (
			
			hotkeys.UnRegisterHotKey hwnd i
			
		)
		
		hotkey_callbacks = #()
		ok
	),
	
	fn sendMessage msg wparam str = (
	
		hwnd = mxsEditorHWND asdotnet:false
		sendmsg.sendMessage hwnd msg wparam str
	
	),



	on create do (
	
		local source = ""
		source  = "using System;\n"
		source += "using System.Collections.Generic;\n"
		source += "using System.Text;\n"
		source += "using System.Runtime.InteropServices;\n"
		source += "using System.Windows.Forms;\n"
		source += "\n"
		source += "namespace WinAPI\n"
		source += "{\n"
		source += "class MessageSnooper : NativeWindow\n" -- LO's message snooper class
		source += "{\n"
		source += "	public delegate void MessageHandler(object msg);\n"
		source += "	public event MessageHandler MessageEvent;\n"
		source += "	protected override void WndProc(ref Message m)\n"
		source += "	{\n"
		source += "		base.WndProc(ref m);\n"
		source += "		if (MessageEvent != null) MessageEvent((object)m);\n"
		source += "	}\n"
		source += "}\n"
		source += "public class Hotkeys\n"
		source += "{\n"
		source += "        public enum WindowKeys\n"
		source += "        {\n"
		source += "            Alt     = 0x0001,\n"
		source += "            Control = 0x0002,\n"
		source += "            Shift   = 0x0004, // Changes!\n"
		source += "            Window  = 0x0008,\n"
		source += "        }\n"
		source += "        [DllImport(\"user32.dll\")]\n"
		source += "        public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);\n"
		source += "        [DllImport(\"user32.dll\")]\n"
		source += "        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);\n"
		source += "\n"
		source += "        public static void RegisterHotkeys( IntPtr hwnd )\n"
		source += "        {\n" -- (WindowKeys.Control|WindowKeys.Shift)
		source += "            RegisterHotKey( hwnd, 1, (int)WindowKeys.Control, (int)Keys.Space);\n"
		source += "        }\n"
		source += "\n"
		source += "        public static void UnregisterHotKeys( IntPtr hwnd )\n"
		source += "        {\n"
		source += "            UnregisterHotKey( hwnd, 1);\n"
		source += "        }\n"
		source += "    }\n"
		source += "public class SendMessageOps\n"
		source += "{\n"
		source += "	[DllImport(\"user32.dll\")]\n"
		source += "	public static extern int SendMessage(Int32 hWnd, int wMsg, int wParam, [MarshalAs(UnmanagedType.LPStr)] string lParam);\n"
		source += "}\n"
		source += "}\n"
				
		csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
		compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"
		compilerParams.ReferencedAssemblies.Add("System.dll");
		compilerParams.ReferencedAssemblies.Add("System.IO.dll");
		compilerParams.ReferencedAssemblies.Add("System.Windows.Forms.dll");		
		compilerParams.GenerateInMemory = on
		compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
		
		
		if (compilerResults.Errors.Count > 0 ) then
		(
			local errs = stringstream ""
			for i = 0 to (compilerResults.Errors.Count-1) do
			(
				local err = compilerResults.Errors.Item[i]
				format "Error:% Line:% Column:% %\n" err.ErrorNumber err.Line err.Column err.ErrorText to:errs
			)
			format "%\n" errs
			undefined
		)
		else
		(

			dll = compilerResults.CompiledAssembly.CreateInstance "WinAPI.Hotkeys"	

			hwnd           = mxsEditorHWND()				
			hotkeys        = dotnetobject "WinAPI.Hotkeys"
			messagesnooper = dotnetobject "WinAPI.MessageSnooper"
			sendmsg        = dotnetobject "WinAPI.SendMessageOps"
			
		)
							
	)
	
)

----------------------- Struct that handles mxseditor related stuff --------------------------------------
struct mxseOps (

	public
	self,
	hwnd,
	apiPath = "C:\files\3D_soft\scripts\maxscript_functions_with_args.txt", 
	startsWithMode        = false, -- False: all lines that contain 'phrase' will be shown in calltip; True: only lines that starts with 'phrase' will be shown.
	queryMaxscriptAPIfile = true,  -- Check external file with function definitions
	queryDocument         = true,  -- Check current document function definitions

	fn getWindowText hwnd:hwnd = (

		marshal = dotnetclass "System.Runtime.InteropServices.Marshal"
		str = ""
		try (
			
			len = windows.sendmessage hwnd 0xE 0 0
			lParam = marshal.AllocHGlobal (marshal.SystemDefaultCharSize*(len+1))
			windows.sendmessage hwnd 0xD (len+1) lParam 
				
			ptr = dotnetobject "System.IntPtr" lParam
			str = marshal.PtrToStringAuto ptr
			marshal.FreeHGlobal ptr
			
		) catch ()
		str
	),
	
	fn mxsEditorHWND asdotnet:false = (
	
		for c in (windows.getchildrenhwnd 0) where c[4] == "MXS_SciTEWindow" do for t in (windows.getchildrenhwnd c[1]) where t[4] == "MXS_Scintilla" do (
		
			if asdotnet then return dotNetObject "system.intptr" t[1] else return t[1]
		
		)
		
	),
	
	fn getFnDefinitionsRegex = (
		
		pattern = "^[ 	]*((mapped)[ 	]+)?(fn|function)+[ 	]+([^=]+)"
		re_options = dotNet.combineEnums (dotNetClass "System.Text.RegularExpressions.RegexOptions").multiline (dotNetClass "System.Text.RegularExpressions.RegexOptions").IgnoreCase (dotNetClass "System.Text.RegularExpressions.RegexOptions").compiled
		regex = dotNetobject "System.Text.RegularExpressions.RegEx"	pattern re_options
		dotNet.setLifetimeControl regex #mxs
		regex
			
	),
	
	fn getFunctionDefinitions regex documentText = (

		matches = regex.Matches documentText

		ss = stringstream ""
		count = [matches.count-1,0]
		for i=0 to count.x do format "%\n" matches.item[i].groups.item[4].value to:ss
		ss as string

	),
	
	fn getFnDefsLineNumbers fnDefs docSrc = (
	
		lineNumbers = #{}
		ss = docSrc as StringStream
		
		functionDefs = FilterString fnDefs "\n"
		
		for f in functionDefs do (

			seek ss 0
			pattern = "*" + f + "*"
			num = [1,0]
			while not eof ss do (
				
				currentLine = readLine ss ignoreStringEscapes:true
				try ( skipToNextLine ss ) catch()
				if MatchPattern currentLine pattern:pattern ignorecase:true do append lineNumbers num.x
				num.x += 1

			)

		)
		
		free ss
		lineNumbers
	),
	
	fn toggleFoldAtLines documentLinesArray hwnd:hwnd = (

		local offset = if isKindOf documentLinesArray BitArray then -1 else 0 -- mxse lines start form zero
		for l in documentLinesArray do windows.sendMessage hwnd 2231 (l + offset) 0
			
	),
	
	fn getWord offset documentText = (

		excludeChars = #(".",","," ","	","\n","'","\"","(",")")
			
		range = [ 0, 0 ]
		
		for i = offset to 0 by -1 while (range.x = i; range.y += 1; findItem excludeChars documentText[i] == 0) do ()
		for i = offset to documentText.count while (range.y += 1; findItem excludeChars documentText[i] == 0) do ()

		trimright(trimleft (substring documentText (range.x+1) (range.y-2)))
		
	),
	
	fn getOffset hwnd:hwnd = (

		windows.sendmessage hwnd 2008 0 0
		
	),
	
	fn getOffsetFromPoint hwnd:hwnd pt: = (

		if pt == unsupplied do pt = mouse.screenpos
			
		mxseWindowPos = windows.getWindowPos hwnd
		windows.sendmessage hwnd 2022 (pt.x - mxseWindowPos.x) (pt.y - mxseWindowPos.y)
		
	),
	
	fn getCurrentWord hwnd:hwnd = (
	
		getWord (getOffset hwnd:hwnd) (getWindowText hwnd:hwnd)
		
	),
	
	fn getWordAtCursor hwnd:hwnd = (
	
		getWord (getOffsetFromPoint hwnd:hwnd) (getWindowText hwnd:hwnd)
		
	),
	
	fn matchPhraseFunctions fnDefinitions phrase startsWith:startsWithMode = (

		local ss = StringStream ""
		local pattern = if startsWith then phrase + "*" else "*" + phrase + "*"
			
		for func in FilterString fnDefinitions "\n" where matchPattern func pattern:pattern ignorecase:true do format "\n%" func to:ss
		
		trimRight( ss as string )
		
	),	
	
	fn matchPhraseAPI API_filename phrase startsWith:startsWithMode = (

		local results = StringStream ""
		local pattern = if startsWith then phrase + "*" else "*" + phrase + "*"
		local str, firstLine = true
		f = openFile API_filename mode:"r"

		while not eof f do (
			
			str = readline f
			
			if matchPattern str pattern:pattern ignorecase:true do (

				if firstLine then ( format "%" str to:results; firstLine = false ) else (
					
					format "\n%" str to:results;
					
				)
				
			)
			
		)
		
		free f
		close f
		
		results as string		
		
	),	
	
	fn query phrase = (

		local doc = api = ""
		
		if queryDocument do (
			
			defs = getFunctionDefinitions (getFnDefinitionsRegex()) (getWindowText())
			doc  = matchPhraseFunctions defs phrase
			
		)
		
		if queryMaxscriptAPIfile and doesFileExist apiPath do (
			
			api = matchPhraseAPI apiPath phrase 
						
		)
		
		api + doc
		
	),	
	
	fn showCalltip offset calltipText hwnd:hwnd = (

		marshal = dotnetclass "System.Runtime.InteropServices.Marshal"
		ptr = marshal.StringToHGlobalUni calltipText

		windows.SendMessage hwnd 2200 offset ptr 
		
	),
	
	fn showCalltipAtCaret = (
	
		local word = getCurrentWord()		

		if word.count > 0 do (
			
			calltip = query word
			if calltip.count > 0 do showCalltip (getOffset()) (trimleft calltip)
				
		)
			
		
	),
	
	fn showCalltipAtMouse = (

		local offset = getOffsetFromPoint()
		local word = getWord offset (getWindowText())
		if word.count > 0 do (
			
			calltip = query word
			if calltip.count > 0 do showCalltip offset (trimleft calltip)
						
		)
		
	),
	
		
	fn init _this = (
		
		_this.hwnd = _this.mxsEditorHWND()
		_this.self = _this
		
	)
	
	
)





----------------------- Custom function example ----------------------------------------------------------------

fn lastModifiedDate = (
	
	try ( ::mxse.sendmsg.sendMessage (::mxse.mxsEditorHWND asdotnet:false) 0xC2 1 ("-- Last Modified: " + (dotnetClass "System.DateTime").Now.ToString();) ) catch( format "Nah work..\n" )
	
)




----------------------- Creating struct instances -------------------------------------------------------------------------------
try ( ::mxse.UnRegisterHotkeys() ) catch() 
::mxse = undefined
gc()

global mxse = mxseHotKeyOps()
global mxs  = mxseOps()
	   mxs.init mxs
-- 	   mxs.apiPath = "some filepath to your functions definitions list"


----------------------- Register Ctrl Alt Shift + Space combinations -------------------------------------

mxse.RegisterHotkey 32 mxs.showCalltipAtCaret ctrl:on
mxse.RegisterHotkey 32 mxs.showCalltipAtMouse ctrl:on shift:on
mxse.RegisterHotkey 32 lastModifiedDate ctrl:on alt:on
	
------------------------------------------------------------------------------------------------------------------------------

	
)

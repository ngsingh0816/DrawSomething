
var members;
var socket;
var nickname;

Tool  = {
	Pencil : 0,
	Line : 1,
	Rect : 2,
	Oval : 3,
	Erase : 4,
}

var tool = Tool.Pencil;
var drawColor = "#000000";
var canDraw = false;
var drawSize = 3;

function Load() {
	
	// Has suffix function
	if (typeof String.prototype.endsWith !== 'function') {
		String.prototype.endsWith = function(suffix) {
			return this.indexOf(suffix, this.length - suffix.length) !== -1;
		};
	}
	
	nickname = "Neil" + Math.floor(Math.random() * 200);
	
	SetupColors();
	ChoosePencil();
	
	$("#Canvas").mousedown(CanvasMouseDown);
	$("#Canvas").mousemove(CanvasMouseMove);
	$("#Canvas").mouseup(CanvasMouseUp);
	$("#Canvas").mouseleave(CanvasMouseLeave);
	$("#Canvas").mouseenter(CanvasMouseEnter);
	
	$("#Effects").mousedown(CanvasMouseDown);
	$("#Effects").mousemove(CanvasMouseMove);
	$("#Effects").mouseup(CanvasMouseUp);
	$("#Effects").mouseleave(CanvasMouseLeave);
	$("#Effects").mouseenter(CanvasMouseEnter);
	
	window.addEventListener('resize', resizeCanvas, false);
	
	function resizeCanvas() {
		// Setup canvas
		var canvas = document.getElementById("Canvas");
		
		// Save image
		var image = new Image();
		image.src = canvas.toDataURL("image/png");
		
		// Fit canvas to container
		canvas.style.width ='calc(100% - 2px)';
		canvas.style.height='calc(100% - 2px)';
		canvas.width = canvas.offsetWidth;
		canvas.height = canvas.offsetHeight;
		
		// Restore image
		var context = canvas.getContext("2d");
		context.drawImage(image, 0, 0, canvas.width, canvas.height);
		
		canvas = document.getElementById("Effects");
		
		// Save image
		image = new Image();
		image.src = canvas.toDataURL("image/png");
		
		// Fit canvas to container
		canvas.style.width ='calc(100% - 2px)';
		canvas.style.height='calc(100% - 2px)';
		canvas.width = canvas.offsetWidth;
		canvas.height = canvas.offsetHeight;
		
		// Restore image
		context = canvas.getContext("2d");
		context.drawImage(image, 0, 0, canvas.width, canvas.height);
	}
	
	resizeCanvas();
	
	Open();
}

function isURL(s) {
	var regexp = /(ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/
	return regexp.test(s);
}

function Open() {
	var IP = "127.0.0.1";
	//var IP = "98.212.129.141";
	socket = new WebSocket("ws://" + IP + ":8888");
	
	/*window.onbeforeunload = closingCode;
	function closingCode(){
		socket.close();
		return null;
	}*/
	
	socket.onopen = function (event) {
		socket.send(JSON.stringify({ "type" : "new", "nickname" : nickname }));
	}
	
	socket.onmessage = function (event) {
		var data = JSON.parse(event.data);
		
		// Update the members
		if (data["type"] == "members") {
			var table = document.getElementById("MemberTable");
			// Clear the table
			table.innerHTML = "";
			
			members = data["members"];
			for (var z = 0; z < members.length; z++) {
				var member = members[z];
				
				if (member["nickname"] == nickname) {
					$("#Canvas").css("cursor", (member["drawing"] == 1) ? "none" : "default");
					$("#Effects").css("cursor", (member["drawing"] == 1) ? "none" : "default");
				}
				
				// Add a row for each member
				var row = table.insertRow(table.rows.length);
				var cell = row.insertCell(0);
				cell.className = "MembersTableRow";
				cell.innerHTML = member["nickname"] + "</br><span style='padding: 0px 15px'>" + member["score"] + " Points</span>";;
				if (member["drawing"] == 1) {
					cell.innerHTML += " <img src='Images/pencil_small.png' width='14' height='14'>";
				}
			}
		} else if (data["type"] == "nickname") {
			nickname = data["nickname"];
		} else if (data["type"] == "message") {
			var chat = document.getElementById("Chat");
			
			var does = false;
			if (chat.scrollTop + chat.clientHeight >= chat.scrollHeight - 10)
				does = true;
			
			var text = data["text"];
			if (isURL(data["text"])) {
				if (data["text"].endsWith(".jpeg") || data["text"].endsWith(".jpg") ||
					data["text"].endsWith(".png") || data["text"].endsWith(".bmp") ||
					data["text"].endsWith(".tiff") || data["text"].endsWith(".tif") ||
					data["text"].endsWith(".gif"))
					text = '<br><img src="' + data["text"] + '">';
				else
					text = '<a href="' + data["text"] + '">' + data["text"] + "</a>";
			}
			chat.innerHTML += "<b>" + data["nickname"] + "</b>: " + text + "</br>";
			
			// The scrolling doesn't work right if you put in an image (probably because it doesn't
			// realize the true height of the image)
			if (does)
				chat.scrollTop = chat.scrollHeight;
		} else if (data["type"] == "clearchat") {
			var chat = document.getElementById("Chat");
			chat.innerHTML = "";
		} else if (data["type"] == "draw" && nickname != data["nickname"]) {
			if (data["tool"] == "pencil") {
				lastX = data["lastX"];
				lastY = data["lastY"];
				DrawPoint(data["x"], data["y"], data["last"], false, data["color"], data["size"]);
			}
		} else if (data["type"] == "turn") {
			canDraw = (data["drawer"] == nickname);
			
			document.getElementById("Word").innerHTML = (canDraw ? data["word"] : "");
			document.getElementById("Time").innerHTML = "Time - 90";
			
			anim = Animation.Start;
			animationThread = setInterval(UpdateEffectsCanvas, 1000.0 / desiredFPS);
			animationTimer = performance.now();
			
		} else if (data["type"] == "end") {
			canDraw = false;
		} else if (data["type"] == "time") {
			document.getElementById("Time").innerHTML = "Time - " + data["time"];
		} else if (data["type"] == "clear") {
			ClearCanvas(data);
		} else if (data["type"] == "tool" && nickname != data["nickname"]) {
			if (data["tool"] == Tool.Line) {
				DrawLine(data["startX"], data["startY"], data["endX"], data["endY"], data["color"], data["size"]);
			}
			else if (data["tool"] == Tool.Rect) {
				DrawRect(data["startX"], data["startY"], data["endX"], data["endY"], data["color"], data["size"]);
			}
			else if (data["tool"] == Tool.Oval) {
				DrawOval(data["startX"], data["startY"], data["endX"], data["endY"], data["color"], data["size"]);
			}
			
			drawTool = false;
			UpdateEffectsCanvas();
		} else if (data["type"] == "tool update" && nickname != data["nickname"]) {
			var backupTool = tool, backupToolColor = toolColor, backupToolSize = toolSize;
			
			tool = data["tool"];
			toolColor = data["color"];
			toolSize = data["size"];
			startToolPointX = data["startX"];
			startToolPointY = data["startY"];
			lastX = data["endX"];
			lastY = data["endY"];
			drawTool = true;
			
			UpdateEffectsCanvas();
			
			tool = backupTool, toolColor = backupToolColor, toolSize = backupToolSize;
		}
	}
	
	socket.onclose = function (event) {
	}
	
	socket.onerror = function (event) {
	}
	
	// TODO: everything breaks when one is open is safari and one in firefox and then the firefox one
	// closes
	
	// TOOD: everything breaks when two are open, then the first is refreshsed, then the second is refreshed
	
}

function SendMessage() {
	var text = document.getElementById("MessageText");
	if (text.value != "")
	{
		var chat = document.getElementById("Chat");
	
		socket.send(JSON.stringify({ "type" : "message", "nickname" : nickname, "text" : text.value }));
	
		text.value = "";
	}
}

var tools = [ "Pencil", "Line", "Rect", "Oval", "Erase" ];
var defaultToolColor = "#00FF00";
var selectedToolColor = "#4CAF50";

function ChoosePencil() {
	for (var z = 0; z < tools.length; z++)
		$("#" + tools[z] + "Tool").css("background-color", defaultToolColor);
	
	$("#PencilTool").css("background-color", selectedToolColor);
	tool = Tool.Pencil;
	
	cursorImage = new Image();
	cursorImage.src = "Images/pencil_medium.png";
}

function ChooseLine() {
	for (var z = 0; z < tools.length; z++)
		$("#" + tools[z] + "Tool").css("background-color", defaultToolColor);
	
	$("#LineTool").css("background-color", selectedToolColor);
	tool = Tool.Line;
	
	cursorImage = new Image();
	cursorImage.src = "Images/pencil_medium.png";
}

function ChooseRect() {
	for (var z = 0; z < tools.length; z++)
		$("#" + tools[z] + "Tool").css("background-color", defaultToolColor);
	
	$("#RectTool").css("background-color", selectedToolColor);
	tool = Tool.Rect;
	
	cursorImage = new Image();
	cursorImage.src = "Images/pencil_medium.png";
}

function ChooseOval() {
	for (var z = 0; z < tools.length; z++)
		$("#" + tools[z] + "Tool").css("background-color", defaultToolColor);
	
	$("#OvalTool").css("background-color", selectedToolColor);
	tool = Tool.Oval;
	
	cursorImage = new Image();
	cursorImage.src = "Images/pencil_medium.png";
}

function ChooseEraser() {
	for (var z = 0; z < tools.length; z++)
		$("#" + tools[z] + "Tool").css("background-color", defaultToolColor);
	
	$("#EraseTool").css("background-color", selectedToolColor);
	tool = Tool.Erase;
	
	cursorImage = new Image();
	cursorImage.src = "Images/eraser_medium.png";
}

colors = [ "000000", "888888", "663300", "FF0000", "880000", "FFC0CB", "FF8800", "FFFF00", "00FF00",
		  "008800", "0088FF", "00FFFF", "0000FF", "FF00FF", "8800FF", "FF0088", "FFFFFF" ];

function SetupColors() {
	var div = document.getElementById("ColorsDiv");
	for (var z = 0; z < colors.length; z++)
	{
		if (z == 0) {
			div.innerHTML += '<button class="ColorButton" style="border-style:inset; background-color:#' + colors[z] + ';" id="' + colors[z] + '" onclick="SelectColor(this.id)"></button>';
		}
		else {
			div.innerHTML += '<button class="ColorButton" style="background-color:#' + colors[z] + ';" id="' + colors[z] + '" onclick="SelectColor(this.id)"></button>';
		}
	}
}

function SelectColor(id) {
	for (var z = 0; z < colors.length; z++)
		$("#" + colors[z]).css("border-style", "solid");
	
	$("#" + id).css("border-style", "inset");
	drawColor = "#" + id;
}

function SizeChange(val) {
	drawSize = val;
}


var mouseDown = false;
var lastX;
var lastY;

var desiredFPS = 60;
var animationTimer = 0;
Animation = {
	None : 0,
	Start : 1,
}
var anim = Animation.None;
var animationThread;

var startToolPointX = 0, startToolPointY = 0;
var drawTool = false, toolColor = "#000000", toolSize = 3;
var cursorImage, mouseOver = false;

function CanvasMouseDown(e) {
	var lastMouseDown = mouseDown;
	
	var canvas = document.getElementById("Canvas");
	var width = canvas.width;
	var height = canvas.height;
	
	mouseDown = true;
	
	var xPos = (e.pageX - this.parentElement.offsetLeft) / width;
	var yPos = (e.pageY - this.parentElement.offsetTop) / height;
	
	if (canDraw && (tool == Tool.Pencil || tool == Tool.Erase)) {
		var color = (tool == Tool.Pencil) ? drawColor: "#FFFFFF";
		DrawPoint(xPos, yPos, false, true, color, drawSize / width);
	}
	
	lastX = xPos;
	lastY = yPos;
		
	if (!lastMouseDown && canDraw) {
		startToolPointX = lastX;
		startToolPointY = lastY;
		
		drawTool = true;
		toolColor = drawColor;
		toolSize = drawSize / width;
	}
}

function CanvasMouseMove(e) {
	mouseOver = true;
	
	var canvas = document.getElementById("Canvas");
	var width = canvas.width;
	var height = canvas.height;
	
	var xPos = (e.pageX - this.parentElement.offsetLeft) / width;
	var yPos = (e.pageY - this.parentElement.offsetTop) / height;
	
	if (mouseDown && canDraw && (tool == Tool.Pencil || tool == Tool.Erase)) {
		var color = (tool == Tool.Pencil) ? drawColor : "#FFFFFF";
		DrawPoint(xPos, yPos, true, true, color, drawSize / width);
	} else if (mouseDown && canDraw) {
		socket.send(JSON.stringify({ "type" : "tool update", "tool" : tool, "startX" : startToolPointX,
								"startY" : startToolPointY, "endX" : xPos, "endY" : yPos,
								"color" : toolColor, "size" : toolSize, "nickname" : nickname }));
	}
	
	lastX = xPos;
	lastY = yPos;
	
	UpdateEffectsCanvas();
}

function CanvasMouseUp(e) {
	mouseDown = false;
	drawTool = false;
	
	var canvas = document.getElementById("Canvas");
	var width = canvas.width;
	var height = canvas.height;
	
	lastX = (e.pageX - this.parentElement.offsetLeft) / width;
	lastY = (e.pageY - this.parentElement.offsetTop) / height;
	
	if (canDraw) {
		if (tool == Tool.Line) {
			DrawLine(startToolPointX, startToolPointY, lastX, lastY, drawColor, drawSize / width);
		}
		else if (tool == Tool.Rect) {
			DrawRect(startToolPointX, startToolPointY, lastX, lastY, drawColor, drawSize / width);
		}
		else if (tool == Tool.Oval) {
			DrawOval(startToolPointX, startToolPointY, lastX, lastY, drawColor, drawSize / width);
		}
		
		socket.send(JSON.stringify({ "type" : "tool", "tool" : tool, "startX" : startToolPointX,
						"startY" : startToolPointY, "endX" : lastX, "endY" : lastY,
						"color" : toolColor, "size" : toolSize, "nickname" : nickname }));
		
		UpdateEffectsCanvas();
	}
}


function CanvasMouseLeave(e) {
	mouseOver = false;
	
	var canvas = document.getElementById("Canvas");
	var width = canvas.width;
	var height = canvas.height;
	
	lastX = (e.pageX - this.parentElement.offsetLeft) / width;
	lastY = (e.pageY - this.parentElement.offsetTop) / height;
	
	UpdateEffectsCanvas();
}

function CanvasMouseEnter(e) {
	mouseOver = true;
	
	var canvas = document.getElementById("Canvas");
	var width = canvas.width;
	var height = canvas.height;
	
	lastX = (e.pageX - this.parentElement.offsetLeft) / width;
	lastY = (e.pageY - this.parentElement.offsetTop) / height;
	
	UpdateEffectsCanvas();
}

function DrawLine(startX, startY, endX, endY, color, dSize) {
	var canvas = document.getElementById("Canvas");
	var context = canvas.getContext("2d");
	context.fillStyle = color;
	context.strokeStyle = color;
	
	var width = canvas.width;
	var height = canvas.height;
	
	context.lineWidth = dSize * 2 * width;
	context.lineJoin = "round";
	
	context.beginPath();
	context.moveTo(startX * width, startY * height);
	context.lineTo(endX * width, endY * height);
	context.closePath();
	context.stroke();
}

function DrawRect(startX, startY, endX, endY, color, dSize) {
	var canvas = document.getElementById("Canvas");
	var context = canvas.getContext("2d");
	context.fillStyle = color;
	context.strokeStyle = color;
	
	var width = canvas.width;
	var height = canvas.height;
	
	context.lineWidth = dSize * 2 * width;
	context.lineJoin = "round";
	
	context.beginPath();
	context.moveTo(startX * width, startY * height);
	context.lineTo(startX * width, endY * height);
	context.lineTo(endX * width, endY * height);
	context.lineTo(endX * width, startY * height);
	context.closePath();
	context.stroke();
}

function DrawOval(startX, startY, endX, endY, color, dSize) {
	var canvas = document.getElementById("Canvas");
	var context = canvas.getContext("2d");
	context.fillStyle = color;
	context.strokeStyle = color;
	
	var width = canvas.width;
	var height = canvas.height;
	
	context.lineWidth = dSize * 2 * width;
	context.lineJoin = "round";
	
	var widthR = (endX - startX) / 2;
	var heightR = (endY - startY) / 2;
	context.beginPath();
	context.ellipse((startX + widthR) * width, (startY + heightR) * height, Math.abs(widthR * width),
					Math.abs(heightR * height), 0, 0, Math.PI * 2);
	context.stroke();
}

function DrawPoint(x, y, last, msg, color, dSize) {
	var canvas = document.getElementById("Canvas");
	var context = canvas.getContext("2d");
	
	context.fillStyle = color;
	context.strokeStyle = color;
	
	var width = canvas.width;
	var height = canvas.height;
	
	if (!last) {
		context.beginPath();
		context.arc(x * width, y * height, dSize * width, 0, Math.PI * 2);
		context.fill();
	} else {
		context.lineWidth = dSize * 2 * width;
		context.lineJoin = "round";
		
		context.beginPath();
		context.moveTo(lastX * width, lastY * height);
		context.lineTo(x * width, y * height);
		context.closePath();
		context.stroke();
	}
	
	if (msg) {
		socket.send(JSON.stringify({ "type" : "draw", "size" : dSize, "x" : x, "y" : y, "tool" : "pencil",
								   "last" : last, "lastX" : lastX, "lastY" : lastY, "nickname" : nickname,
								   "color" : color }));
	}
}

function ClearCanvas(data) {
	if ((data == undefined) ||
		(data["nickname"] == undefined) ||
		(data["nickname"] != undefined && data["nickname"] != nickname)) {
		var canvas = document.getElementById("Canvas");
		var context = canvas.getContext("2d");
		
		context.clearRect(0, 0, canvas.width, canvas.height);
	}
}

function ClearCanvasMessage() {
	if (canDraw) {
		ClearCanvas();
		socket.send(JSON.stringify({ "type" : "clear", "nickname" : nickname }));
	}
}

function UpdateEffectsCanvas() {
	var canvas = document.getElementById("Effects");
	var context = canvas.getContext("2d");
	
	context.clearRect(0, 0, canvas.width, canvas.height);
	
	var width = canvas.width;
	var height = canvas.height;
	
	if (drawTool) {
		if (tool == Tool.Line) {
			context.fillStyle = toolColor;
			context.strokeStyle = toolColor;
			
			context.lineWidth = toolSize * 2 * width;
			context.lineJoin = "round";
			
			context.beginPath();
			context.moveTo(startToolPointX * width, startToolPointY * height);
			context.lineTo(lastX * width, lastY * height);
			context.closePath();
			context.stroke();
		} else if (tool == Tool.Rect) {
			context.fillStyle = toolColor;
			context.strokeStyle = toolColor;
			
			context.lineWidth = toolSize * 2 * width;
			context.lineJoin = "round";
			
			context.beginPath();
			context.moveTo(startToolPointX * width, startToolPointY * height);
			context.lineTo(startToolPointX * width, lastY * height);
			context.lineTo(lastX * width, lastY * height);
			context.lineTo(lastX * width, startToolPointY * height);
			context.closePath();
			context.stroke();
		} else if (tool == Tool.Oval) {
			context.fillStyle = toolColor;
			context.strokeStyle = toolColor;
			
			context.lineWidth = toolSize * 2 * width;
			context.lineJoin = "round";
			
			var widthR = (lastX - startToolPointX) / 2;
			var heightR = (lastY - startToolPointY) / 2;
			context.beginPath();
			context.ellipse((startToolPointX + widthR) * width, (startToolPointY + heightR) * height,
							Math.abs(widthR * width), Math.abs(heightR * height), 0, 0, Math.PI * 2);
			context.stroke();
		}
	}
	
	// Draw the cursor
	if (mouseOver && canDraw) {
		var ratio = cursorImage.width / cursorImage.height;
		var cursorSize = drawSize * (32.0 / 3);
		
		if (tool == Tool.Erase) {
			var scale = (drawSize / 3 / 2);
			cursorSize /= 2;
			context.drawImage(cursorImage, lastX * width - 9 * scale, lastY * height - cursorSize / ratio + 8 * scale, cursorSize, cursorSize / ratio);
		} else {
			context.drawImage(cursorImage, lastX * width, lastY * height - cursorSize / ratio,
						  cursorSize, cursorSize / ratio);
		}
	}
	
	if (anim == Animation.Start) {
		var time = performance.now() - animationTimer;
		if (time >= 1000) {
			anim = Animation.None;
			clearInterval(animationThread);
			return;
		} else {
			context.fillStyle = "rgba(0, 0, 0, " + (1 - time / 1000) + ")";
			context.font = "italic " + Math.floor(60 + (time / 1000) * 100) + "pt Arvo";
			context.textAlign = "center";
			context.fillText("Start", canvas.width / 2, canvas.height / 2);
		}
	}
}

function resize(arr, size, defval) {
  var delta = arr.length - size;
  if (delta > 0) {
    arr.length = size;
  }
  else {
    while (delta++ < 0) { arr.push(defval); }
  }
}
// geting canvas by id c
// var c = document.getElementById("c");
var c = document.createElement('canvas');
c.setAttribute('id', 'c_matrix');
c.setAttribute('style', 'position: fixed; top: 0px; left: 0px; z-index: 0; opacity: 0.75;');
// c = $('#bgMatrix');
//making the canvas full screen
c.height = window.innerHeight;
c.width = window.innerWidth;
// $('#bgMatrix').height(window.innerHeight);
// $('#bgMatrix').width(window.innerWidth);
document.body.appendChild(c);
var ctx = c.getContext("2d");



//chinese characters - taken from the unicode charset
var matrix = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわゐゑを";
//converting the string into an array of single characters
matrix = matrix.split("");

var font_size = 10;
var columns = c.width / font_size; //number of columns for the rain
//an array of drops - one per column
var drops = [];
//x below is the x coordinate
//1 = y co-ordinate of the drop(same for every drop initially)
resize(drops, columns, c.height / font_size);

//drawing the characters
function draw() {
  //Black BG for the canvas
  //translucent BG to show trail
  ctx.fillStyle = "rgba(0, 0, 0, 0.04)";
  ctx.fillRect(0, 0, c.width, c.height);

  ctx.fillStyle = "#0F0"; //green text
  ctx.font = font_size + "px arial";
  //looping over drops
  for (var i = 0; i < drops.length; i++) {
    //a random chinese character to print
    var text = matrix[Math.floor(Math.random() * matrix.length)];
    //x = i*font_size, y = value of drops[i]*font_size
    ctx.fillText(text, i * font_size, drops[i] * font_size);

    //sending the drop back to the top randomly after it has crossed the screen
    //adding a randomness to the reset to make the drops scattered on the Y axis
    if (drops[i] * font_size > c.height && Math.random() > 0.975)
      drops[i] = 0;

    //incrementing Y coordinate
    drops[i]++;
  }
  setTimeout(draw, 35);
}
setTimeout(draw, 35);

$(window).resize(function () {
  $('#c_matrix').attr('height', window.innerHeight);
  $('#c_matrix').attr('width', window.innerWidth);
  columns = $('#c_matrix').attr('width') / font_size;
  resize(drops, columns, 0);
});

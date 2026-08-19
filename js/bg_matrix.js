(() => {
  const chars = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわゐゑを";
  const fontSize = 10;
  let canvas, ctx, drops, w, h;

  const init = () => {
    if (!canvas) {
      canvas = document.createElement('canvas');
      canvas.style.cssText = 'position:fixed;top:0;left:0;z-index:0;opacity:0.75;pointer-events:none;';
      document.body.appendChild(canvas);
      ctx = canvas.getContext('2d');
    }
    w = canvas.width = window.innerWidth;
    h = canvas.height = window.innerHeight;
    drops = Array(Math.ceil(w / fontSize)).fill(1);
  };

  const draw = () => {
    ctx.fillStyle = 'rgba(0,0,0,0.05)';
    ctx.fillRect(0, 0, w, h);
    ctx.fillStyle = '#0F0';
    ctx.font = `${fontSize}px monospace`;

    for (let i = 0; i < drops.length; i++) {
      const text = chars[Math.floor(Math.random() * chars.length)];
      ctx.fillText(text, i * fontSize, drops[i] * fontSize);
      if (drops[i] * fontSize > h && Math.random() > 0.975) drops[i] = 0;
      drops[i]++;
    }
    requestAnimationFrame(draw);
  };

  window.addEventListener('resize', init);
  init();
  draw();
})();

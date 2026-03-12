#!/bin/bash
# Create a new game folder with template
# Usage: ./scripts/new-game.sh <game-name>

set -e

if [ -z "$1" ]; then
    echo "Usage: ./scripts/new-game.sh <game-name>"
    exit 1
fi

GAME_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_DIR="$SCRIPT_DIR/../games"

if [ -d "$GAMES_DIR/$GAME_NAME" ]; then
    echo "❌ Game folder already exists: $GAMES_DIR/$GAME_NAME"
    exit 1
fi

echo "Creating game: $GAME_NAME"

mkdir -p "$GAMES_DIR/$GAME_NAME"

cat > "$GAMES_DIR/$GAME_NAME/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Game Title</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { overflow: hidden; background: #0d0d1a; }
        #gameCanvas { display: block; }
    </style>
</head>
<body>
    <canvas id="gameCanvas"></canvas>
    <script>
        // Your Three.js code here
        const canvas = document.getElementById('gameCanvas');
        const scene = new THREE.Scene();
        const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
        renderer.setSize(window.innerWidth, window.innerHeight);
        camera.position.z = 5;

        const geometry = new THREE.BoxGeometry();
        const material = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
        const cube = new THREE.Mesh(geometry, material);
        scene.add(cube);

        function animate() {
            requestAnimationFrame(animate);
            cube.rotation.x += 0.01;
            cube.rotation.y += 0.01;
            renderer.render(scene, camera);
        }
        animate();

        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });
    </script>
</body>
</html>
HTMLEOF

echo "✅ Created $GAMES_DIR/$GAME_NAME/index.html"
echo ""
echo "Next steps:"
echo "  1. Edit $GAMES_DIR/$GAME_NAME/index.html with your game"
echo "  2. Initialize git: git init && git add . && git commit -m 'Initial'"
echo "  3. Add remote: git remote add origin <your-repo-url>"
echo "  4. Deploy: ./scripts/deploy.sh $GAME_NAME"

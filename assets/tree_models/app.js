/* global THREE, Chaput */

(() => {
    const canvas = document.getElementById("c");

    // ---------- Flutter <-> JS Bridge ----------
    function send(msg) {
        try { Chaput.postMessage(String(msg)); } catch (_) {}
    }

    // Flutter will call: window.setChaputParams({...});
    // Example payload:
    // { treeModel:"tree_003.glb", autoRotate:true, rotateSpeed:0.35, bg:"#000000", quality:"high" }
    window.__chaputParams = null;
    window.setChaputParams = (p) => { window.__chaputParams = p; };

    // ---------- Prevent webview "feel" ----------
    window.addEventListener("contextmenu", (e) => e.preventDefault());
    document.addEventListener("gesturestart", (e) => e.preventDefault());

    // ---------- Defaults ----------
    const DEFAULTS = {
        treeModel: "tree_003.glb",
        autoRotate: true,
        rotateSpeed: 0.35,
        bg: "#000000",
        quality: "high", // "low" | "mid" | "high"
        enableControls: true
    };

    // ---------- Renderer / Scene ----------
    const renderer = new THREE.WebGLRenderer({
        canvas,
        antialias: true,         // iPhone 11 ok; gerekirse false yap
        alpha: false,
        powerPreference: "high-performance"
    });
    renderer.setClearColor(0x000000, 1);

    // Color space (three version'a göre bazı isimler değişebilir)
    if (renderer.outputColorSpace !== undefined) {
        // newer three
        renderer.outputColorSpace = THREE.SRGBColorSpace;
    } else if (renderer.outputEncoding !== undefined) {
        // older three
        renderer.outputEncoding = THREE.sRGBEncoding;
    }

    const scene = new THREE.Scene();

    // Camera
    const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 200);
    camera.position.set(0.0, 1.35, 3.2);

    // Controls (native hissi için yumuşak)
    const controls = new THREE.OrbitControls(camera, canvas);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.enablePan = false;
    controls.minDistance = 1.6;
    controls.maxDistance = 6.0;
    controls.target.set(0, 1.1, 0);

    // Lights (performant)
    const hemi = new THREE.HemisphereLight(0xffffff, 0x222233, 1.0);
    hemi.position.set(0, 2, 0);
    scene.add(hemi);

    const dir = new THREE.DirectionalLight(0xffffff, 1.25);
    dir.position.set(2.5, 4.5, 2.0);
    dir.castShadow = false;
    scene.add(dir);

    // Optional subtle fill
    const fill = new THREE.DirectionalLight(0xffffff, 0.35);
    fill.position.set(-2.0, 1.5, -1.5);
    scene.add(fill);

    // ---------- Resize ----------
    function setSize() {
        const w = window.innerWidth;
        const h = window.innerHeight;

        // Pixel ratio cap (perf)
        const dpr = window.devicePixelRatio || 1;
        const cap =
            currentParams.quality === "low" ? 1.0 :
                currentParams.quality === "mid" ? 1.3 :
                    1.6;

        renderer.setPixelRatio(Math.min(dpr, cap));
        renderer.setSize(w, h, false);

        camera.aspect = w / h;
        camera.updateProjectionMatrix();
    }

    window.addEventListener("resize", setSize);

    // ---------- Model loading ----------
    let modelRoot = null;
    let mixer = null; // if model has animations
    const loader = new THREE.GLTFLoader();

    function disposeModel(obj) {
        if (!obj) return;
        obj.traverse((child) => {
            if (child.geometry) child.geometry.dispose?.();
            if (child.material) {
                const mats = Array.isArray(child.material) ? child.material : [child.material];
                mats.forEach((m) => {
                    // textures
                    for (const k in m) {
                        const v = m[k];
                        if (v && v.isTexture) v.dispose?.();
                    }
                    m.dispose?.();
                });
            }
        });
        scene.remove(obj);
    }

    function fitToView(obj) {
        // Center & scale model nicely
        const box = new THREE.Box3().setFromObject(obj);
        const size = box.getSize(new THREE.Vector3());
        const center = box.getCenter(new THREE.Vector3());

        obj.position.sub(center); // center to origin

        // scale to desired height
        const desiredH = 2.0;
        const scale = desiredH / Math.max(0.0001, size.y);
        obj.scale.setScalar(scale);

        // after scaling, update controls target
        controls.target.set(0, desiredH * 0.55, 0);
        controls.update();
    }

    function loadTree(glbName) {
        return new Promise((resolve, reject) => {
            const path = glbName; // same folder as index.html
            loader.load(
                path,
                (gltf) => {
                    resolve(gltf);
                },
                undefined,
                (err) => reject(err)
            );
        });
    }

    // ---------- Animation loop ----------
    let raf = 0;
    let lastTs = 0;

    function animate(ts) {
        raf = requestAnimationFrame(animate);
        const dt = Math.min(0.033, (ts - lastTs) / 1000) || 0.016;
        lastTs = ts;

        // auto rotate (model root)
        if (currentParams.autoRotate && modelRoot) {
            modelRoot.rotation.y += currentParams.rotateSpeed * dt;
        }

        if (mixer) mixer.update(dt);

        controls.update();
        renderer.render(scene, camera);
    }

    // ---------- Params + Init ----------
    let currentParams = { ...DEFAULTS };

    async function initWithParams(p) {
        try {
            currentParams = { ...DEFAULTS, ...(p || {}) };

            // background
            renderer.setClearColor(new THREE.Color(currentParams.bg), 1);

            // controls enable
            controls.enabled = !!currentParams.enableControls;

            // size
            setSize();

            // unload old model (if any)
            if (modelRoot) {
                disposeModel(modelRoot);
                modelRoot = null;
            }
            mixer = null;

            // load glb
            const gltf = await loadTree(currentParams.treeModel);

            modelRoot = gltf.scene || gltf.scenes?.[0];
            if (!modelRoot) throw new Error("GLB has no scene");

            // optional: reduce heavy stuff
            modelRoot.traverse((c) => {
                // disable frustum issues for skinned/complex meshes
                c.frustumCulled = true;
            });

            scene.add(modelRoot);
            fitToView(modelRoot);

            // animations (if any)
            if (gltf.animations && gltf.animations.length) {
                mixer = new THREE.AnimationMixer(modelRoot);
                gltf.animations.forEach((clip) => mixer.clipAction(clip).play());
            }

            send("loaded");
        } catch (e) {
            console.error(e);
            send("error:" + (e?.message || String(e)));
        }
    }

    // Wait flutter params, but also allow direct load fallback
    let waited = 0;
    const poll = setInterval(() => {
        waited += 16;
        if (window.__chaputParams) {
            clearInterval(poll);
            initWithParams(window.__chaputParams);
        } else if (waited > 2000) {
            // fallback after 2s
            clearInterval(poll);
            initWithParams(DEFAULTS);
        }
    }, 16);

    // Start render loop immediately (black screen won't stutter)
    animate(0);
})();
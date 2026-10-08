import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Interactive two-link kinematics for both legs of the EXO-SLT model.
///
/// The source GLB is a flat CAD export, so the JavaScript below discovers the
/// left/right assemblies from their geometry and applies virtual hip and knee
/// pivots without rewriting the model asset.
class ExoKinematicModel extends StatelessWidget {
  final ValueChanged<String>? onJointSelected;

  const ExoKinematicModel({super.key, this.onJointSelected});

  static const _controls = r'''
    <div class="exo-help" id="exo-help">Hông và gối kéo lên/xuống</div>
    <button class="exo-reset" id="exo-reset" type="button">Đặt lại</button>

    <button class="exo-hip-handle exo-right" id="right-hip"
      slot="hotspot-right-hip" data-position="0.188m 0.958m -0.060m"
      data-normal="1m 0m 0m" aria-label="Kéo khớp hông phải lên hoặc xuống">
      <span>↕</span>
    </button>
    <button class="exo-knee-handle exo-right" id="right-knee"
      slot="hotspot-right-knee" data-position="0.188m 0.539m -0.052m"
      data-normal="1m 0m 0m" aria-label="Kéo khớp gối phải lên hoặc xuống">
      <span>↕</span>
    </button>
    <button class="exo-foot exo-right" id="right-ankle"
      slot="hotspot-right-ankle" data-position="0.188m 0.160m -0.052m"
      data-normal="1m 0m 0m" aria-label="Điểm cuối chân phải">
      <span>P</span>
    </button>

    <button class="exo-hip-handle exo-left" id="left-hip"
      slot="hotspot-left-hip" data-position="-0.225m 0.958m -0.060m"
      data-normal="-1m 0m 0m" aria-label="Kéo khớp hông trái lên hoặc xuống">
      <span>↕</span>
    </button>
    <button class="exo-knee-handle exo-left" id="left-knee"
      slot="hotspot-left-knee" data-position="-0.225m 0.539m -0.052m"
      data-normal="-1m 0m 0m" aria-label="Kéo khớp gối trái lên hoặc xuống">
      <span>↕</span>
    </button>
    <button class="exo-foot exo-left" id="left-ankle"
      slot="hotspot-left-ankle" data-position="-0.225m 0.160m -0.052m"
      data-normal="-1m 0m 0m" aria-label="Điểm cuối chân trái">
      <span>T</span>
    </button>
  ''';

  static const _styles = r'''
    model-viewer { overflow: hidden; }
    .exo-help {
      position: absolute;
      left: 12px;
      top: 12px;
      padding: 7px 10px;
      border-radius: 12px;
      color: #f8fafc;
      background: rgba(15, 23, 42, .76);
      font: 600 12px/1.2 system-ui, sans-serif;
      pointer-events: none;
      backdrop-filter: blur(6px);
    }
    .exo-reset {
      position: absolute;
      right: 12px;
      top: 12px;
      z-index: 4;
      border: 1px solid rgba(255,255,255,.65);
      border-radius: 12px;
      padding: 7px 10px;
      color: #0f172a;
      background: rgba(255,255,255,.88);
      font: 700 12px/1.2 system-ui, sans-serif;
    }
    .exo-joint, .exo-hip-handle, .exo-knee-handle, .exo-foot {
      box-sizing: border-box;
      border-radius: 999px;
      padding: 0;
      transform: translate(-50%, -50%);
      box-shadow: 0 2px 9px rgba(15, 23, 42, .45);
    }
    .exo-joint {
      width: 15px;
      height: 15px;
      border: 3px solid white;
      pointer-events: none;
    }
    .exo-hip-handle, .exo-knee-handle {
      border: 3px solid white;
      color: white;
      touch-action: none;
      cursor: grab;
      font-family: system-ui, sans-serif;
      font-weight: 800;
    }
    .exo-hip-handle, .exo-knee-handle {
      width: 28px;
      height: 28px;
      font-size: 16px;
      line-height: 22px;
    }
    .exo-foot {
      width: 34px;
      height: 34px;
      border: 3px solid white;
      color: white;
      pointer-events: none;
      font: 800 11px/28px system-ui, sans-serif;
    }
    .exo-hip-handle:active, .exo-knee-handle:active {
      cursor: grabbing;
      transform: translate(-50%, -50%) scale(1.12);
    }
    .exo-right { background: #0ea5e9; }
    .exo-left { background: #f97316; }
    .exo-error { background: rgba(153, 27, 27, .86); }
  ''';

  static const _kinematics = r'''
    (() => {
      const viewer = document.querySelector('#exo-kinematic-viewer');
      const help = document.querySelector('#exo-help');
      const reset = document.querySelector('#exo-reset');

      const legs = {
        right: {
          x: 0.188,
          hip: { y: 0.958, z: -0.060 },
          knee: { y: 0.539, z: -0.052 },
          ankle: { y: 0.160, z: -0.052 },
          thigh: [], shin: [], hipAngle: 0, kneeAngle: 0
        },
        left: {
          x: -0.225,
          hip: { y: 0.958, z: -0.060 },
          knee: { y: 0.539, z: -0.052 },
          ankle: { y: 0.160, z: -0.052 },
          thigh: [], shin: [], hipAngle: 0, kneeAngle: 0
        }
      };

      let scene;
      let assemblyRoot;
      let matrixTemplate;

      const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

      function modelScene() {
        const key = Object.getOwnPropertySymbols(viewer)
          .find((symbol) => symbol.description === 'scene');
        return key ? viewer[key] : null;
      }

      function findAssemblyRoot(root) {
        let result = null;
        root.traverse((node) => {
          if (!result && node.name === 'Default') result = node;
        });
        return result;
      }

      function boundsRelativeTo(object, root) {
        root.updateWorldMatrix(true, true);
        const inverseRoot = root.matrixWorld.clone().invert();
        const min = [Infinity, Infinity, Infinity];
        const max = [-Infinity, -Infinity, -Infinity];

        object.traverse((node) => {
          const geometry = node.geometry;
          if (!geometry) return;
          if (!geometry.boundingBox) geometry.computeBoundingBox();
          const box = geometry.boundingBox;
          if (!box) return;

          for (const x of [box.min.x, box.max.x]) {
            for (const y of [box.min.y, box.max.y]) {
              for (const z of [box.min.z, box.max.z]) {
                const point = box.min.clone().set(x, y, z)
                  .applyMatrix4(node.matrixWorld)
                  .applyMatrix4(inverseRoot);
                min[0] = Math.min(min[0], point.x);
                min[1] = Math.min(min[1], point.y);
                min[2] = Math.min(min[2], point.z);
                max[0] = Math.max(max[0], point.x);
                max[1] = Math.max(max[1], point.y);
                max[2] = Math.max(max[2], point.z);
              }
            }
          }
        });

        return {
          x: (min[0] + max[0]) / 2,
          y: (min[1] + max[1]) / 2,
          z: (min[2] + max[2]) / 2
        };
      }

      function discoverSegments() {
        legs.right.thigh = [];
        legs.right.shin = [];
        legs.left.thigh = [];
        legs.left.shin = [];

        assemblyRoot.updateWorldMatrix(true, true);
        const inverseRoot = assemblyRoot.matrixWorld.clone().invert();
        const meshes = [];
        assemblyRoot.traverse((node) => {
          if (node.geometry) meshes.push(node);
        });

        for (const node of meshes) {
          const center = boundsRelativeTo(node, assemblyRoot);
          if (!Number.isFinite(center.x)) continue;

          const side = center.x > 0.12
            ? 'right'
            : center.x < -0.12
              ? 'left'
              : null;
          if (!side || center.y >= 1.09) continue;

          // The CAD model has bearing centres at y=.958 and y=.539. Parts
          // below the lower bearing move with the shin; the rest move with
          // the thigh. A small tolerance keeps knee hardware together.
          const segment = center.y < 0.55 ? 'shin' : 'thigh';
          node.userData.exoBaseRootMatrix = inverseRoot.clone()
            .multiply(node.matrixWorld);
          node.userData.exoParentRootInverse = inverseRoot.clone()
            .multiply(node.parent.matrixWorld)
            .invert();
          legs[side][segment].push(node);
          matrixTemplate ??= node.matrix;
        }
      }

      function rotationAround(y, z, angle) {
        const result = matrixTemplate.clone().identity().makeTranslation(0, y, z);
        const rotation = matrixTemplate.clone().identity().makeRotationX(angle);
        const restore = matrixTemplate.clone().identity().makeTranslation(0, -y, -z);
        return result.multiply(rotation).multiply(restore);
      }

      function setNodeTransform(node, transform) {
        node.matrix.copy(node.userData.exoParentRootInverse)
          .multiply(transform)
          .multiply(node.userData.exoBaseRootMatrix);
        node.matrix.decompose(node.position, node.quaternion, node.scale);
        node.updateMatrix();
      }

      function pointAfterAngles(leg) {
        const l1 = leg.hip.y - leg.knee.y;
        const l2 = leg.knee.y - leg.ankle.y;
        const q1 = leg.hipAngle;
        const q2 = leg.kneeAngle;
        return {
          kneeY: leg.hip.y - l1 * Math.cos(q1),
          kneeZ: leg.hip.z + l1 * Math.sin(q1),
          ankleY: leg.hip.y - l1 * Math.cos(q1) - l2 * Math.cos(q1 - q2),
          ankleZ: leg.hip.z + l1 * Math.sin(q1) + l2 * Math.sin(q1 - q2)
        };
      }

      function moveHotspot(name, x, y, z) {
        const position = `${x}m ${y}m ${z}m`;
        const element = document.querySelector(`#${name}`);
        if (element) element.dataset.position = position;
        if (viewer.updateHotspot) {
          viewer.updateHotspot({ name: `hotspot-${name}`, position });
        }
      }

      function applyLeg(side) {
        const leg = legs[side];
        const hipTransform = rotationAround(leg.hip.y, leg.hip.z, -leg.hipAngle);
        // Knee flexion is opposite to hip flexion: the thigh moves forward
        // while the shin folds backward, like lifting the leg for a step.
        const kneeTransform = rotationAround(leg.knee.y, leg.knee.z, leg.kneeAngle);
        const shinTransform = hipTransform.clone().multiply(kneeTransform);

        for (const node of leg.thigh) setNodeTransform(node, hipTransform);
        for (const node of leg.shin) setNodeTransform(node, shinTransform);
        assemblyRoot.updateWorldMatrix(true, true);

        const points = pointAfterAngles(leg);
        moveHotspot(`${side}-knee`, leg.x, points.kneeY, points.kneeZ);
        moveHotspot(`${side}-ankle`, leg.x, points.ankleY, points.ankleZ);
        scene.queueRender();
      }

      function attachHipDrag(side) {
        const handle = document.querySelector(`#${side}-hip`);
        let pointerId = null;
        let startY = 0;
        let startHipAngle = 0;

        handle.addEventListener('pointerdown', (event) => {
          event.preventDefault();
          event.stopPropagation();
          pointerId = event.pointerId;
          startY = event.clientY;
          startHipAngle = legs[side].hipAngle;
          handle.setPointerCapture(pointerId);
          viewer.cameraControls = false;
        });

        handle.addEventListener('pointermove', (event) => {
          if (event.pointerId !== pointerId) return;
          event.preventDefault();
          // Pulling the hip control upward lifts the thigh; pulling it down
          // returns the thigh to the straight standing position.
          legs[side].hipAngle = clamp(
            startHipAngle - (event.clientY - startY) * 0.008,
            0,
            55 * Math.PI / 180
          );
          applyLeg(side);
        });

        const finish = (event) => {
          if (event.pointerId !== pointerId) return;
          pointerId = null;
          viewer.cameraControls = true;
        };
        handle.addEventListener('pointerup', finish);
        handle.addEventListener('pointercancel', finish);
      }

      function attachKneeDrag(side) {
        const handle = document.querySelector(`#${side}-knee`);
        let pointerId = null;
        let startY = 0;
        let startKneeAngle = 0;

        handle.addEventListener('pointerdown', (event) => {
          event.preventDefault();
          event.stopPropagation();
          pointerId = event.pointerId;
          startY = event.clientY;
          startKneeAngle = legs[side].kneeAngle;
          handle.setPointerCapture(pointerId);
          viewer.cameraControls = false;
        });

        handle.addEventListener('pointermove', (event) => {
          if (event.pointerId !== pointerId) return;
          event.preventDefault();
          // Pulling the knee control upward flexes the shin backward;
          // pulling it downward extends the leg again.
          legs[side].kneeAngle = clamp(
            startKneeAngle - (event.clientY - startY) * 0.010,
            0,
            120 * Math.PI / 180
          );
          applyLeg(side);
        });

        const finish = (event) => {
          if (event.pointerId !== pointerId) return;
          pointerId = null;
          viewer.cameraControls = true;
        };
        handle.addEventListener('pointerup', finish);
        handle.addEventListener('pointercancel', finish);
      }

      function attachManualSelection(side, joint) {
        const handle = document.querySelector(`#${side}-${joint}`);
        if (!handle) return;
        handle.addEventListener('click', (event) => {
          event.preventDefault();
          event.stopPropagation();
          if (typeof ExoManual !== 'undefined') {
            ExoManual.postMessage(JSON.stringify({side, joint}));
          }
        });
      }

      function initialise() {
        scene = modelScene();
        if (!scene || !scene._model) {
          help.textContent = 'Không truy cập được scene 3D';
          help.classList.add('exo-error');
          return;
        }
        assemblyRoot = findAssemblyRoot(scene._model);
        if (!assemblyRoot) {
          help.textContent = 'Không tìm thấy cụm EXO-SLT';
          help.classList.add('exo-error');
          return;
        }

        discoverSegments();
        if (!matrixTemplate || legs.right.shin.length < 10 || legs.left.shin.length < 10) {
          help.textContent = `Không xác định được cụm chân ` +
            `(P:${legs.right.thigh.length}/${legs.right.shin.length}, ` +
            `T:${legs.left.thigh.length}/${legs.left.shin.length})`;
          help.classList.add('exo-error');
          return;
        }

        attachHipDrag('right');
        attachHipDrag('left');
        attachKneeDrag('right');
        attachKneeDrag('left');
        attachManualSelection('right', 'hip');
        attachManualSelection('right', 'knee');
        attachManualSelection('left', 'hip');
        attachManualSelection('left', 'knee');
        applyLeg('right');
        applyLeg('left');
        help.textContent = 'Kéo hông để nâng đùi · Kéo gối để gập chân';
      }

      reset.addEventListener('click', (event) => {
        event.stopPropagation();
        for (const side of ['right', 'left']) {
          legs[side].hipAngle = 0;
          legs[side].kneeAngle = 0;
          applyLeg(side);
        }
      });

      if (viewer.loaded) initialise();
      else viewer.addEventListener('load', initialise, { once: true });
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    return ModelViewer(
      id: 'exo-kinematic-viewer',
      src: 'assets/EXO_SLT.glb',
      alt: 'Interactive EXO-SLT lower-limb exoskeleton',
      loading: Loading.eager,
      backgroundColor: Colors.transparent,
      cameraControls: true,
      autoRotate: false,
      disablePan: false,
      touchAction: TouchAction.none,
      interactionPrompt: InteractionPrompt.none,
      cameraOrbit: '70deg 82deg 2.15m',
      cameraTarget: '0m 0.78m -0.06m',
      minCameraOrbit: 'auto 35deg 1.2m',
      maxCameraOrbit: 'auto 145deg 4m',
      shadowIntensity: 0.9,
      exposure: 1.05,
      innerModelViewerHtml: _controls,
      relatedCss: _styles,
      relatedJs: _kinematics,
      debugLogging: false,
      javascriptChannels: onJointSelected == null
          ? null
          : {
              JavascriptChannel(
                'ExoManual',
                onMessageReceived: (message) =>
                    onJointSelected!(message.message),
              ),
            },
    );
  }
}

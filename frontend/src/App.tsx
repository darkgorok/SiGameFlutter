import { useEffect, useRef, useState } from 'react';
import { BrowserRouter } from 'react-router-dom';

import { AppRouter } from './app/AppRouter';
import { gameRepository } from './features/game/data/gameRepository';
import { InitialProfileSetupPage } from './features/profile/ui/InitialProfileSetupPage';
import { ensureAnonymousAuth, watchAuthState } from './shared/firebase/auth';
import { firebaseConfigured } from './shared/firebase/client';
import { I18nProvider } from './shared/i18n/I18nProvider';
import { useI18n } from './shared/i18n/i18nContext';
import { readLocalProfile, writeLocalProfile } from './shared/profile/localProfile';

const initialLocalProfile = readLocalProfile();

function LiquidGlassBackdrop() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) {
      return () => {};
    }
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return () => {};
    }

    const root = document.documentElement;
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const coarsePointer = window.matchMedia('(pointer: coarse)').matches;
    const dpr = Math.min(window.devicePixelRatio || 1, 1.75);
    let width = 0;
    let height = 0;
    let rafId = 0;
    let pointerX = window.innerWidth * 0.5;
    let pointerY = window.innerHeight * 0.36;
    let targetPointerX = pointerX;
    let targetPointerY = pointerY;

    const resize = () => {
      width = window.innerWidth;
      height = window.innerHeight;
      canvas.width = Math.floor(width * dpr);
      canvas.height = Math.floor(height * dpr);
      canvas.style.width = `${width}px`;
      canvas.style.height = `${height}px`;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };

    const paintBlob = (x: number, y: number, radius: number, color: string, alpha: number) => {
      const gradient = ctx.createRadialGradient(x, y, radius * 0.08, x, y, radius);
      gradient.addColorStop(0, color);
      gradient.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.globalAlpha = alpha;
      ctx.fillStyle = gradient;
      ctx.beginPath();
      ctx.arc(x, y, radius, 0, Math.PI * 2);
      ctx.fill();
    };

    const render = (nowMs: number) => {
      const now = nowMs * 0.001;
      pointerX += (targetPointerX - pointerX) * 0.08;
      pointerY += (targetPointerY - pointerY) * 0.08;

      ctx.clearRect(0, 0, width, height);
      ctx.globalCompositeOperation = 'screen';

      const cx = width * 0.5;
      const cy = height * 0.48;
      for (let i = 0; i < 6; i += 1) {
        const orbit = (i + 1) * 36;
        const speed = 0.12 + i * 0.02;
        const phase = now * speed + i * 0.65;
        const bx = cx + Math.cos(phase) * orbit + Math.sin(now * 0.35 + i) * 40;
        const by = cy + Math.sin(phase * 1.12) * (orbit * 0.72);
        const radius = Math.max(180, Math.min(width, height) * (0.22 - i * 0.012));
        const color =
          i % 2 === 0 ? 'rgba(138,192,255,0.85)' : 'rgba(104,148,228,0.78)';
        paintBlob(bx, by, radius, color, 0.1 + i * 0.008);
      }

      paintBlob(pointerX, pointerY, Math.min(width, height) * 0.32, 'rgba(208,232,255,0.92)', 0.17);
      paintBlob(
        width - pointerX * 0.8,
        height - pointerY * 0.75,
        Math.min(width, height) * 0.26,
        'rgba(102,145,228,0.82)',
        0.12,
      );

      ctx.globalCompositeOperation = 'lighter';
      ctx.globalAlpha = 0.1;
      ctx.strokeStyle = 'rgba(194,223,255,0.8)';
      ctx.lineWidth = 1;
      const lines = coarsePointer ? 8 : 14;
      const step = Math.max(26, height / lines);
      for (let i = 0; i < lines; i += 1) {
        const yBase = i * step;
        ctx.beginPath();
        for (let x = 0; x <= width; x += 20) {
          const wave = Math.sin((x + now * 220 + i * 32) * 0.012) * 8;
          const lensPull = ((pointerY - yBase) / Math.max(220, height * 0.35)) * 4;
          const y = yBase + wave + lensPull;
          if (x === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        }
        ctx.stroke();
      }

      ctx.globalCompositeOperation = 'source-over';
      ctx.globalAlpha = 0.16;
      const vignette = ctx.createRadialGradient(
        width * 0.5,
        height * 0.6,
        Math.min(width, height) * 0.2,
        width * 0.5,
        height * 0.6,
        Math.max(width, height) * 0.9,
      );
      vignette.addColorStop(0, 'rgba(14,24,40,0)');
      vignette.addColorStop(1, 'rgba(4,10,18,0.62)');
      ctx.fillStyle = vignette;
      ctx.fillRect(0, 0, width, height);
      ctx.globalAlpha = 1;

      root.style.setProperty('--liquid-pointer-x', `${pointerX.toFixed(1)}px`);
      root.style.setProperty('--liquid-pointer-y', `${pointerY.toFixed(1)}px`);

      if (!reduceMotion) {
        rafId = window.requestAnimationFrame(render);
      }
    };

    const onPointerMove = (event: PointerEvent) => {
      targetPointerX = event.clientX;
      targetPointerY = event.clientY;
    };

    resize();
    render(0);

    window.addEventListener('resize', resize);
    window.addEventListener('pointermove', onPointerMove, { passive: true });

    return () => {
      window.removeEventListener('resize', resize);
      window.removeEventListener('pointermove', onPointerMove);
      window.cancelAnimationFrame(rafId);
    };
  }, []);

  return <canvas className="liquid-canvas" ref={canvasRef} aria-hidden="true" />;
}

function AppShell() {
  const { t } = useI18n();
  const [booting, setBooting] = useState(firebaseConfigured);
  const [authError, setAuthError] = useState<string | null>(null);
  const [profileReady, setProfileReady] = useState(Boolean(initialLocalProfile.nickname));
  const [profileChecking, setProfileChecking] = useState(
    firebaseConfigured && !initialLocalProfile.nickname,
  );

  useEffect(() => {
    if (!firebaseConfigured) {
      return () => {};
    }

    let cancelled = false;
    let offProfile: (() => void) | null = null;

    const offAuth = watchAuthState((user) => {
      if (cancelled) {
        return;
      }
      if (offProfile) {
        offProfile();
        offProfile = null;
      }

      if (!user) {
        setProfileReady(false);
        setProfileChecking(false);
        setBooting(false);
        return;
      }

      setBooting(false);

      const localProfile = readLocalProfile();
      if (localProfile.nickname) {
        setProfileReady(true);
        setProfileChecking(false);
        return;
      }

      setProfileChecking(true);
      let settled = false;
      offProfile = gameRepository.watchProfile(user.uid, (profile) => {
        if (cancelled || settled) {
          return;
        }
        settled = true;

        if (profile?.nickname) {
          writeLocalProfile({ nickname: profile.nickname, avatarUrl: profile.avatarUrl });
          setProfileReady(true);
        } else {
          setProfileReady(false);
        }
        setProfileChecking(false);

        if (offProfile) {
          offProfile();
          offProfile = null;
        }
      });
    });

    void ensureAnonymousAuth()
      .then(() => {
        if (!cancelled) {
          setBooting(false);
        }
      })
      .catch((reason) => {
        if (!cancelled) {
          setAuthError(reason instanceof Error ? reason.message : 'Auth failed');
          setBooting(false);
        }
      });

    return () => {
      cancelled = true;
      if (offProfile) {
        offProfile();
      }
      offAuth();
    };
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    let rafId = 0;
    let targetX = window.innerWidth * 0.5;
    let targetY = window.innerHeight * 0.3;
    let currentX = targetX;
    let currentY = targetY;
    let activeGlassEl: HTMLElement | null = null;
    let audioCtx: AudioContext | null = null;
    const interactiveSelector =
      '.panel, .room-card, .nav-link, button, .button-link, .modal-card, input, select, textarea';
    const contrastSelector = '.panel, .room-card, .app-header, .modal-card, input, select, textarea';
    const isCoarsePointer = window.matchMedia('(pointer: coarse)').matches;

    const updateContrastBoost = () => {
      const items = document.querySelectorAll<HTMLElement>(contrastSelector);
      for (const item of items) {
        const rect = item.getBoundingClientRect();
        const centerY = rect.top + rect.height * 0.5;
        const normalized = centerY / Math.max(1, window.innerHeight);
        const boost = Math.max(0, 0.26 - Math.abs(normalized - 0.5) * 0.32);
        item.style.setProperty('--contrast-boost', boost.toFixed(3));
      }
    };

    const updateLocalHighlight = (event: PointerEvent) => {
      const targetNode = event.target as HTMLElement | null;
      const nextGlassEl = targetNode?.closest<HTMLElement>(interactiveSelector) ?? null;
      if (activeGlassEl !== nextGlassEl) {
        if (activeGlassEl) {
          activeGlassEl.classList.remove('liquid-active');
        }
        activeGlassEl = nextGlassEl;
        if (activeGlassEl) {
          activeGlassEl.classList.add('liquid-active');
        }
      }

      if (!nextGlassEl) {
        return;
      }
      const rect = nextGlassEl.getBoundingClientRect();
      const localX = ((event.clientX - rect.left) / Math.max(1, rect.width)) * 100;
      const localY = ((event.clientY - rect.top) / Math.max(1, rect.height)) * 100;
      const x = Math.max(0, Math.min(100, localX));
      const y = Math.max(0, Math.min(100, localY));
      nextGlassEl.style.setProperty('--local-x', `${x.toFixed(2)}%`);
      nextGlassEl.style.setProperty('--local-y', `${y.toFixed(2)}%`);
    };

    const updateDockFocus = (x: number, y: number) => {
      const links = document.querySelectorAll<HTMLElement>('.nav-link');
      for (const link of links) {
        const rect = link.getBoundingClientRect();
        const cx = rect.left + rect.width * 0.5;
        const cy = rect.top + rect.height * 0.5;
        const dx = Math.abs(x - cx);
        const dy = Math.abs(y - cy);
        const distance = Math.sqrt(dx * dx + dy * dy);
        const influenceRadius = 180;
        const focus = Math.max(0, 1 - distance / influenceRadius);
        link.style.setProperty('--dock-focus', focus.toFixed(3));
      }
    };

    const playUiClick = () => {
      try {
        if (!audioCtx) {
          const Ctx = window.AudioContext;
          audioCtx = Ctx ? new Ctx() : null;
        }
        if (!audioCtx) {
          return;
        }
        if (audioCtx.state === 'suspended') {
          void audioCtx.resume();
        }
        const now = audioCtx.currentTime;
        const gain = audioCtx.createGain();
        gain.gain.setValueAtTime(0.0001, now);
        gain.gain.exponentialRampToValueAtTime(0.018, now + 0.005);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.055);
        gain.connect(audioCtx.destination);

        const osc = audioCtx.createOscillator();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(1380, now);
        osc.frequency.exponentialRampToValueAtTime(960, now + 0.05);
        osc.connect(gain);
        osc.start(now);
        osc.stop(now + 0.06);
      } catch {
        // ignore audio failures
      }
    };

    const sync = () => {
      currentX += (targetX - currentX) * 0.14;
      currentY += (targetY - currentY) * 0.14;
      root.style.setProperty('--pointer-x', `${currentX}px`);
      root.style.setProperty('--pointer-y', `${currentY}px`);
      root.style.setProperty('--pointer-nx', `${(currentX / window.innerWidth - 0.5).toFixed(4)}`);
      root.style.setProperty('--pointer-ny', `${(currentY / window.innerHeight - 0.5).toFixed(4)}`);
      if (!isCoarsePointer) {
        updateContrastBoost();
      }
      rafId = window.requestAnimationFrame(sync);
    };

    const onMove = (event: PointerEvent) => {
      targetX = event.clientX;
      targetY = event.clientY;
      updateLocalHighlight(event);
      updateDockFocus(event.clientX, event.clientY);
    };

    const onScroll = () => {
      const max = Math.max(1, document.body.scrollHeight - window.innerHeight);
      const progress = window.scrollY / max;
      root.style.setProperty('--scroll-progress', progress.toFixed(4));
      updateContrastBoost();
    };

    const onResize = () => {
      updateContrastBoost();
    };

    const onPointerLeave = () => {
      if (activeGlassEl) {
        activeGlassEl.classList.remove('liquid-active');
        activeGlassEl = null;
      }
      const links = document.querySelectorAll<HTMLElement>('.nav-link');
      for (const link of links) {
        link.style.setProperty('--dock-focus', '0');
      }
    };

    const onPointerDown = (event: PointerEvent) => {
      const node = (event.target as HTMLElement | null)?.closest<HTMLElement>(
        'button, .button-link, .nav-link',
      );
      if (!node) {
        return;
      }
      node.classList.remove('haptic-pulse');
      void node.offsetWidth;
      node.classList.add('haptic-pulse');
      window.setTimeout(() => node.classList.remove('haptic-pulse'), 420);
      playUiClick();
    };

    if (isCoarsePointer) {
      root.classList.add('coarse-pointer');
    } else {
      root.classList.remove('coarse-pointer');
      window.addEventListener('pointermove', onMove);
      window.addEventListener('pointerleave', onPointerLeave);
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onResize);
    window.addEventListener('pointerdown', onPointerDown, { capture: true });
    onScroll();
    onResize();
    sync();

    return () => {
      if (!isCoarsePointer) {
        window.removeEventListener('pointermove', onMove);
        window.removeEventListener('pointerleave', onPointerLeave);
      }
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onResize);
      window.removeEventListener('pointerdown', onPointerDown, { capture: true });
      window.cancelAnimationFrame(rafId);
    };
  }, []);

  if (!firebaseConfigured) {
    return <div className="center">{t('app.firebase_missing')}</div>;
  }

  if (booting) {
    return <div className="center">{t('app.boot')}</div>;
  }

  if (authError) {
    return <div className="center error">{authError}</div>;
  }

  if (profileChecking) {
    return <div className="center">{t('app.profile_check')}</div>;
  }

  if (!profileReady) {
    return <InitialProfileSetupPage onSaved={() => setProfileReady(true)} />;
  }

  return (
    <BrowserRouter>
      <AppRouter />
    </BrowserRouter>
  );
}

export default function App() {
  const turbulenceRef = useRef<SVGFETurbulenceElement | null>(null);
  const displacementRef = useRef<SVGFEDisplacementMapElement | null>(null);

  useEffect(() => {
    const turbulence = turbulenceRef.current;
    const displacement = displacementRef.current;
    if (!turbulence || !displacement) {
      return () => {};
    }

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduceMotion) {
      return () => {};
    }

    let rafId = 0;
    const tick = (nowMs: number) => {
      const now = nowMs * 0.001;
      const fx = 0.0105 + Math.sin(now * 0.24) * 0.0022;
      const fy = 0.018 + Math.cos(now * 0.2) * 0.0032;
      turbulence.setAttribute('baseFrequency', `${fx.toFixed(5)} ${fy.toFixed(5)}`);
      turbulence.setAttribute('seed', `${Math.floor(10 + (Math.sin(now * 0.12) + 1) * 9)}`);

      const scale = 2.5 + (Math.sin(now * 0.33) + 1) * 1.15;
      displacement.setAttribute('scale', scale.toFixed(2));
      rafId = window.requestAnimationFrame(tick);
    };

    rafId = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(rafId);
  }, []);

  return (
    <>
      <LiquidGlassBackdrop />
      <svg width="0" height="0" aria-hidden="true" focusable="false" className="glass-filter-defs">
        <filter id="liquid-distort" x="-20%" y="-20%" width="140%" height="140%">
          <feTurbulence
            ref={turbulenceRef}
            type="fractalNoise"
            baseFrequency="0.012 0.02"
            numOctaves="2"
            seed="13"
            result="noise"
          />
          <feDisplacementMap
            ref={displacementRef}
            in="SourceGraphic"
            in2="noise"
            scale="2.8"
            xChannelSelector="R"
            yChannelSelector="G"
          />
        </filter>
      </svg>
      <div className="app-root-layer">
        <I18nProvider>
          <AppShell />
        </I18nProvider>
      </div>
    </>
  );
}

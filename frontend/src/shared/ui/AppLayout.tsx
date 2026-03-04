import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useI18n } from '../i18n/i18nContext';


export function AppLayout() {
  const { t } = useI18n();
  const location = useLocation();

  const links = [
    { to: '/', label: t('nav.home') },
    { to: '/rooms', label: t('nav.rooms') },
    { to: '/settings', label: t('nav.settings') },
    { to: '/pack-editor', label: t('nav.packs') },
  ];

  return (
    <div className="app-shell">
      <header className="app-header">
        <h1>BrainBlitz</h1>
        <nav>
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === '/'}
              className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}
            >
              {link.label}
            </NavLink>
          ))}
        </nav>
      </header>
      <main className="app-main">
        <div className="route-view" key={location.pathname}>
          <Outlet />
        </div>
      </main>
    </div>
  );
}

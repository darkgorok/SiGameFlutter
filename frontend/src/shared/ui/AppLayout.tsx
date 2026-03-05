import { Link, Outlet, useLocation } from 'react-router-dom';
import { useI18n } from '../i18n/i18nContext';


export function AppLayout() {
  const { t } = useI18n();
  const location = useLocation();
  const isHome = location.pathname === '/';

  return (
    <div className="app-shell">
      <main className="app-main">
        {isHome ? null : (
          <div className="page-back-row">
            <Link className="button-link ghost-button" to="/">
              {t('common.back_to_menu')}
            </Link>
          </div>
        )}
        <div className="route-view" key={location.pathname}>
          <Outlet />
        </div>
      </main>
    </div>
  );
}

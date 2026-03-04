import { lazy, Suspense } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { AppLayout } from '../shared/ui/AppLayout';

const HomePage = lazy(() =>
  import('../features/home/ui/HomePage').then((module) => ({ default: module.HomePage })),
);
const PackEditorPage = lazy(() =>
  import('../features/packs/ui/PackEditorPage').then((module) => ({ default: module.PackEditorPage })),
);
const ProfilePage = lazy(() =>
  import('../features/profile/ui/ProfilePage').then((module) => ({ default: module.ProfilePage })),
);
const RoomsPage = lazy(() =>
  import('../features/rooms/ui/RoomsPage').then((module) => ({ default: module.RoomsPage })),
);
const SettingsPage = lazy(() =>
  import('../features/settings/ui/SettingsPage').then((module) => ({ default: module.SettingsPage })),
);
const RoomPage = lazy(() =>
  import('../features/game/ui/RoomPage').then((module) => ({ default: module.RoomPage })),
);
const RoomEditorPage = lazy(() =>
  import('../features/game/ui/RoomEditorPage').then((module) => ({ default: module.RoomEditorPage })),
);

export function AppRouter() {
  return (
    <Suspense fallback={<div className="center">Loading...</div>}>
      <Routes>
        <Route element={<AppLayout />}>
          <Route path="/" element={<HomePage />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/rooms" element={<RoomsPage />} />
          <Route path="/pack-editor" element={<PackEditorPage />} />
          <Route path="/room/:roomId" element={<RoomPage />} />
          <Route path="/room/:roomId/editor" element={<RoomEditorPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </Suspense>
  );
}

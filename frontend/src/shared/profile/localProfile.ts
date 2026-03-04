const NICK_KEY = 'profile_nickname';
const AVATAR_KEY = 'profile_avatar';

export type LocalProfile = {
  nickname: string;
  avatarUrl: string;
};

export function readLocalProfile(): LocalProfile {
  return {
    nickname: localStorage.getItem(NICK_KEY)?.trim() ?? '',
    avatarUrl: localStorage.getItem(AVATAR_KEY)?.trim() ?? '',
  };
}

export function writeLocalProfile(profile: LocalProfile): void {
  localStorage.setItem(NICK_KEY, profile.nickname.trim());
  localStorage.setItem(AVATAR_KEY, profile.avatarUrl.trim());
}

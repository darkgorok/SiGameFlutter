function normalizeAliases(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }

  const cleaned = raw
    .map((value) => String(value || '').trim())
    .filter((value) => value.length > 0);

  return [...new Set(cleaned)].slice(0, 20);
}

function normalizeAnswer(value) {
  return String(value || '').trim().toLowerCase();
}

function ensureVoiceRole(role, spectatorRole = 'spectator') {
  return role !== spectatorRole;
}

function toFiniteNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function normalizeQuestionType(value) {
  const kind = normalizeQuestionKind(value);

  if (
    kind === 'cat_in_bag' ||
    kind === 'secret' ||
    kind === 'secret_public_price' ||
    kind === 'secret_no_question'
  ) {
    return 'cat_in_bag';
  }
  if (
    kind === 'wager' ||
    kind === 'stake' ||
    kind === 'stake_all'
  ) {
    return 'wager';
  }
  if (kind === 'closest_number') {
    return 'closest_number';
  }
  return 'normal';
}

function normalizeQuestionKind(value) {
  const raw = String(value || 'normal').trim().toLowerCase();
  const compact = raw.replace(/[\s\-]+/g, '_');

  if (compact === 'cat' || compact === 'cat_in_bag' || compact === 'bagcat') {
    return 'cat_in_bag';
  }
  if (compact === 'auction' || compact === 'wager') {
    return 'wager';
  }
  if (compact === 'stake') {
    return 'stake';
  }
  if (compact === 'stake_all' || compact === 'stakeall') {
    return 'stake_all';
  }
  if (compact === 'closest_number') {
    return 'closest_number';
  }

  if (compact === 'simple') {
    return 'simple';
  }
  if (compact === 'with_button' || compact === 'withbutton') {
    return 'with_button';
  }
  if (compact === 'for_all' || compact === 'forall') {
    return 'for_all';
  }
  if (compact === 'for_yourself' || compact === 'foryourself') {
    return 'for_yourself';
  }
  if (compact === 'no_risk' || compact === 'norisk' || compact === 'sponsored') {
    return 'no_risk';
  }

  if (compact === 'secret') {
    return 'secret';
  }
  if (compact === 'secret_public_price' || compact === 'secretpublicprice') {
    return 'secret_public_price';
  }
  if (compact === 'secret_no_question' || compact === 'secretnoquestion') {
    return 'secret_no_question';
  }

  return 'normal';
}

function getQuestionBehavior(value) {
  const kind = normalizeQuestionKind(value);
  const type = normalizeQuestionType(kind);
  const oneShotKinds = new Set([
    'cat_in_bag',
    'secret',
    'secret_public_price',
    'secret_no_question',
    'wager',
    'stake',
    'stake_all',
    'for_yourself',
  ]);

  return {
    kind,
    type,
    requiresTarget: type === 'cat_in_bag',
    requiresWager: type === 'wager',
    isClosestNumber: type === 'closest_number',
    isForAll: kind === 'for_all' || kind === 'stake_all',
    isNoRisk: kind === 'no_risk',
    autoResolveWithoutAnswer: kind === 'secret_no_question',
    oneShot: oneShotKinds.has(kind),
  };
}

module.exports = {
  normalizeAliases,
  normalizeAnswer,
  ensureVoiceRole,
  toFiniteNumber,
  normalizeQuestionType,
  normalizeQuestionKind,
  getQuestionBehavior,
};

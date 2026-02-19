const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeQuestionType,
  normalizeQuestionKind,
  getQuestionBehavior,
} = require('../src/game/utils');

test('normalizes SI and legacy question types into engine canonical types', () => {
  const cases = [
    ['normal', 'normal'],
    ['simple', 'normal'],
    ['with_button', 'normal'],
    ['for_all', 'normal'],
    ['no_risk', 'normal'],
    ['cat', 'cat_in_bag'],
    ['cat_in_bag', 'cat_in_bag'],
    ['bagcat', 'cat_in_bag'],
    ['secret', 'cat_in_bag'],
    ['secret_public_price', 'cat_in_bag'],
    ['secret_no_question', 'cat_in_bag'],
    ['stake', 'wager'],
    ['stake_all', 'wager'],
    ['auction', 'wager'],
    ['closest_number', 'closest_number'],
    ['unknown_type', 'normal'],
  ];

  for (const [input, expected] of cases) {
    assert.equal(normalizeQuestionType(input), expected, `input=${input}`);
  }
});

test('normalizes canonical question kinds for SI-specific types', () => {
  const cases = [
    ['bagcat', 'cat_in_bag'],
    ['stake', 'stake'],
    ['stake_all', 'stake_all'],
    ['secret_public_price', 'secret_public_price'],
    ['secret_no_question', 'secret_no_question'],
    ['for_all', 'for_all'],
    ['for_yourself', 'for_yourself'],
    ['no_risk', 'no_risk'],
    ['sponsored', 'no_risk'],
  ];

  for (const [input, expected] of cases) {
    assert.equal(normalizeQuestionKind(input), expected, `input=${input}`);
  }
});

test('builds behavior flags for special kinds', () => {
  const noRisk = getQuestionBehavior('no_risk');
  assert.equal(noRisk.isNoRisk, true);
  assert.equal(noRisk.oneShot, false);

  const secretNoQuestion = getQuestionBehavior('secret_no_question');
  assert.equal(secretNoQuestion.autoResolveWithoutAnswer, true);
  assert.equal(secretNoQuestion.requiresTarget, true);

  const stakeAll = getQuestionBehavior('stake_all');
  assert.equal(stakeAll.requiresWager, true);
  assert.equal(stakeAll.isForAll, true);
});

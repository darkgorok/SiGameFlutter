import { describe, expect, it } from 'vitest';

import { parseLocalPack } from './localPack';

describe('parseLocalPack', () => {
  it('parses object pack format', () => {
    const result = parseLocalPack({
      name: 'Demo',
      questions: [
        {
          theme: 'History',
          text: 'Q?',
          answer: 'A',
          cost: 200,
          round: 2,
          type: 'wager',
          mediaUrl: 'https://x',
          mediaType: 'image',
          aliases: ['a1', 'a1', 'a2'],
        },
      ],
    });

    expect(result.name).toBe('Demo');
    expect(result.questions).toHaveLength(1);
    expect(result.questions[0]).toMatchObject({
      theme: 'History',
      text: 'Q?',
      answer: 'A',
      cost: 200,
      round: 2,
      type: 'wager',
      mediaType: 'image',
      aliases: ['a1', 'a2'],
    });
  });

  it('parses legacy list format and bagcat alias', () => {
    const result = parseLocalPack([
      {
        theme: 'Theme',
        text: 'Question',
        answer: 'Answer',
        type: 'bagcat',
      },
    ]);

    expect(result.name).toBe('Pack');
    expect(result.questions).toHaveLength(1);
    expect(result.questions[0].type).toBe('cat_in_bag');
  });

  it('parses blitz pack format v1', () => {
    const result = parseLocalPack({
      format: 'blitz-pack',
      version: 1,
      name: 'Blitz Demo',
      rounds: [
        {
          themes: [{ id: 't1', title: 'Science' }],
          questions: [
            {
              themeId: 't1',
              text: 'H2O?',
              answer: 'Water',
              cost: 300,
              type: 'normal',
            },
          ],
        },
      ],
      finalRound: {
        themes: [{ id: 'f1', title: 'Final' }],
        questions: [
          {
            themeId: 'f1',
            text: 'Final Q',
            answer: 'Final A',
            cost: 500,
            type: 'wager',
          },
        ],
      },
    });

    expect(result.name).toBe('Blitz Demo');
    expect(result.questions).toHaveLength(2);
    expect(result.questions[0]).toMatchObject({
      theme: 'Science',
      text: 'H2O?',
      answer: 'Water',
      cost: 300,
      round: 1,
      type: 'normal',
    });
    expect(result.questions[1]).toMatchObject({
      theme: 'Final',
      text: 'Final Q',
      answer: 'Final A',
      cost: 500,
      round: 2,
      type: 'wager',
    });
  });
});

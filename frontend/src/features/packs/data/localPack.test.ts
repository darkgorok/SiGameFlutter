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
});

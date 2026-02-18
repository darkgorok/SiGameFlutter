function createContentCommandHandlers(deps) {
  const {
    db,
    FieldValue,
    functionsLib,
    PLAYER_ROLE,
    normalizeAliases,
    normalizeQuestionType,
    normalizeQuestionKind,
    requireHost,
    assertRoomMember,
    canEditContent,
    isFeatureEnabled,
    logEvent,
  } = deps;

  const ALLOWED_MEDIA_TYPES = new Set(['none', 'image', 'audio', 'video']);

  function normalizeMediaType(value) {
    const mediaType = String(value || 'none').trim().toLowerCase();
    return ALLOWED_MEDIA_TYPES.has(mediaType) ? mediaType : 'none';
  }

  function normalizeQuestionPayload(raw, { strict = true } = {}) {
    const q = raw && typeof raw === 'object' ? raw : {};
    const theme = String(q.theme || '').trim() || 'No theme';
    const text = String(q.text || '').trim();
    const answer = String(q.answer || '').trim();
    const roundRaw = Number(q.round || 1);
    const costRaw = Number(q.cost || 100);
    const round = Number.isFinite(roundRaw) && roundRaw >= 1
      ? Math.floor(roundRaw)
      : 1;
    const cost = Number.isFinite(costRaw) && costRaw >= 0
      ? Math.floor(costRaw)
      : 100;

    if (strict && !text) {
      throw new functionsLib.https.HttpsError(
        'invalid-argument',
        'Question text is required',
      );
    }
    if (strict && !answer) {
      throw new functionsLib.https.HttpsError(
        'invalid-argument',
        'Question answer is required',
      );
    }

    return {
      theme,
      text,
      answer,
      cost,
      round,
      kind: normalizeQuestionKind(q.kind || q.type),
      type: normalizeQuestionType(q.kind || q.type),
      mediaUrl: String(q.mediaUrl || '').trim(),
      mediaType: normalizeMediaType(q.mediaType),
      aliases: normalizeAliases(q.aliases || []),
    };
  }

  function buildQuestionDoc(question, uid) {
    return {
      ...question,
      used: false,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
    };
  }

  return {
    async add_question({ uid, payload, roomId, roomRef }) {
      await requireHost(roomRef, uid);
      const question = normalizeQuestionPayload(payload);
      await roomRef.collection('questions').add(buildQuestionDoc(question, uid));
      await logEvent(roomId, uid, 'question_add', 'Question added');
      return { ok: true };
    },

    async add_questions_bulk({ uid, payload, roomId, roomRef }) {
      if (!await isFeatureEnabled('bulkQuestionImport')) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Bulk question import is disabled',
        );
      }
      await requireHost(roomRef, uid);
      const questions = Array.isArray(payload.questions) ? payload.questions : [];
      if (questions.length === 0) {
        return { ok: true, imported: 0 };
      }

      const batch = db.batch();
      let imported = 0;
      for (const item of questions.slice(0, 500)) {
        const q = normalizeQuestionPayload(item);
        const qRef = roomRef.collection('questions').doc();
        batch.set(qRef, buildQuestionDoc(q, uid));
        imported += 1;
      }
      await batch.commit();
      await logEvent(roomId, uid, 'question_add_bulk', `Questions imported: ${imported}`);
      return { ok: true, imported };
    },

    async update_question({ uid, payload, roomId, roomRef }) {
      const role = await assertRoomMember(roomRef, uid);
      if (!canEditContent(role)) {
        throw new functionsLib.https.HttpsError(
          'permission-denied',
          'Only host or editor can update question',
        );
      }

      const questionId = String(payload.questionId || payload.id || '').trim();
      if (!questionId) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'questionId required');
      }

      const questionRef = roomRef.collection('questions').doc(questionId);
      const questionSnap = await questionRef.get();
      if (!questionSnap.exists) {
        throw new functionsLib.https.HttpsError('not-found', 'Question not found');
      }
      const existing = questionSnap.data() || {};
      if (existing.used === true) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Cannot edit used question',
        );
      }

      const patch = payload.question && typeof payload.question === 'object'
        ? payload.question
        : payload;
      const merged = { ...existing, ...patch };
      const hasType = Object.prototype.hasOwnProperty.call(patch, 'type');
      const hasKind = Object.prototype.hasOwnProperty.call(patch, 'kind');
      if (hasType && !hasKind) {
        merged.kind = patch.type;
      } else if (hasKind && !hasType) {
        merged.type = patch.kind;
      }
      delete merged.questionId;
      delete merged.id;
      delete merged.question;
      delete merged.used;
      delete merged.createdAt;
      delete merged.createdBy;
      delete merged.updatedAt;
      delete merged.updatedBy;

      const normalized = normalizeQuestionPayload(merged);
      await questionRef.set(
        {
          ...normalized,
          updatedBy: uid,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      await logEvent(roomId, uid, 'question_update', `Question updated: ${questionId}`);
      return { ok: true };
    },

    async delete_question({ uid, payload, roomId, roomRef }) {
      const role = await assertRoomMember(roomRef, uid);
      if (!canEditContent(role)) {
        throw new functionsLib.https.HttpsError(
          'permission-denied',
          'Only host or editor can delete question',
        );
      }

      const questionId = String(payload.questionId || payload.id || '').trim();
      if (!questionId) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'questionId required');
      }

      const questionRef = roomRef.collection('questions').doc(questionId);
      const questionSnap = await questionRef.get();
      if (!questionSnap.exists) {
        throw new functionsLib.https.HttpsError('not-found', 'Question not found');
      }
      const question = questionSnap.data() || {};
      if (question.used === true) {
        throw new functionsLib.https.HttpsError(
          'failed-precondition',
          'Cannot delete used question',
        );
      }

      await questionRef.delete();
      await logEvent(roomId, uid, 'question_delete', `Question deleted: ${questionId}`);
      return { ok: true };
    },

    async save_pack({ uid, payload, roomId, roomRef }) {
      const role = await assertRoomMember(roomRef, uid);
      if (!canEditContent(role)) {
        throw new functionsLib.https.HttpsError(
          'permission-denied',
          'Only host or editor can save pack',
        );
      }
      const packName = String(payload.name || '').trim() || `Pack-${roomId}`;
      const questions = await roomRef.collection('questions').get();
      const items = questions.docs.map((q) => normalizeQuestionPayload(q.data(), { strict: false }));

      const existing = await db
        .collection('packs')
        .where('name', '==', packName)
        .orderBy('version', 'desc')
        .limit(1)
        .get();
      const version = existing.empty ? 1 : Number(existing.docs.first.data().version || 1) + 1;
      const packRef = db.collection('packs').doc();
      await packRef.set({
        name: packName,
        version,
        questionCount: items.length,
        questions: items,
        createdBy: uid,
        roomId,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await logEvent(roomId, uid, 'pack_save', `Pack saved: ${packName} v${version}`);
      return { ok: true, packId: packRef.id, version };
    },

    async apply_pack({ uid, payload, roomId, roomRef }) {
      const packId = String(payload.packId || '');
      if (!packId) {
        throw new functionsLib.https.HttpsError('invalid-argument', 'packId required');
      }
      const role = await assertRoomMember(roomRef, uid);
      if (!(role === PLAYER_ROLE.HOST || role === PLAYER_ROLE.EDITOR)) {
        throw new functionsLib.https.HttpsError(
          'permission-denied',
          'Only host or editor can apply pack',
        );
      }
      const packSnap = await db.collection('packs').doc(packId).get();
      if (!packSnap.exists) {
        throw new functionsLib.https.HttpsError('not-found', 'Pack not found');
      }
      const pack = packSnap.data() || {};
      const questions = Array.isArray(pack.questions) ? pack.questions : [];
      const batch = db.batch();
      let imported = 0;
      for (const q of questions.slice(0, 500)) {
        const normalized = normalizeQuestionPayload(q);
        const qRef = roomRef.collection('questions').doc();
        batch.set(qRef, buildQuestionDoc(normalized, uid));
        imported += 1;
      }
      await batch.commit();
      await logEvent(roomId, uid, 'pack_apply', `Pack applied: ${pack.name || packId}`);
      return { ok: true, imported };
    },
  };
}

module.exports = {
  createContentCommandHandlers,
};

// Express routes for the contract in docs/CONTRACT.md.
import express from 'express';
import { DomainError } from './domain/errors.js';

export function createApp(service, { logger = console, log = true } = {}) {
  const app = express();
  app.disable('x-powered-by');

  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    const t0 = process.hrtime.bigint();
    res.on('finish', () => {
      if (!log) return;
      const ms = Number(process.hrtime.bigint() - t0) / 1e6;
      logger.log(`${req.method} ${req.path} ${res.statusCode} ${ms.toFixed(0)}ms`);
    });
    next();
  });
  app.use(express.json({ limit: '256kb' }));

  const h = (fn) => (req, res, next) => Promise.resolve().then(() => fn(req, res)).then((out) => {
    if (out !== undefined) res.json(out);
  }).catch(next);

  const auth = (req, res, next) => {
    const m = String(req.get('authorization') ?? '').match(/^Bearer\s+(\S+)$/i);
    const user = m ? service.userForToken(m[1]) : null;
    if (!user) return next(new DomainError('UNAUTHORIZED', 'Please log in again.', 401));
    req.user = user;
    next();
  };

  // health & auth
  app.get('/api/health', h(() => service.health()));
  app.post('/api/auth/otp', h((req) => service.requestOtp(req.body ?? {})));
  app.post('/api/auth/verify', h((req) => service.verify(req.body ?? {})));

  app.use('/api', auth);
  app.get('/api/me', h((req) => service.me(req.user)));
  app.get('/api/users', h((req) => service.profiles(String(req.query.ids ?? '').split(',').filter(Boolean))));
  app.get('/api/me/orders', h((req) => service.myOrders(req.user)));
  app.get('/api/me/wallet', h((req) => service.wallet(req.user)));

  // communities
  app.get('/api/communities', h((req) => service.communities(req.query.q)));
  app.get('/api/communities/:id', h((req) => service.community(req.params.id)));
  app.post('/api/communities/:id/join', h((req) => service.joinCommunity(req.user, req.params.id, req.body ?? {})));
  app.get('/api/communities/:id/buckets', h((req) => service.listBuckets(req.params.id, req.query, req.user.id)));

  // buckets, shares, holds
  app.post('/api/buckets', h((req) => service.createBucket(req.user, req.body ?? {})));
  app.get('/api/buckets/:id', h((req) => service.getBucket(req.params.id, req.user.id)));
  app.post('/api/buckets/:id/shares', h((req) => service.joinBucket(req.user, req.params.id, req.body ?? {})));
  app.post('/api/buckets/:id/close', h((req) => service.closeBucket(req.params.id)));
  app.post('/api/holds/:id/authorize', h((req) => service.authorizeHold(req.user, req.params.id, req.body ?? {})));
  app.delete('/api/shares/:id', h((req) => service.leaveShare(req.user, req.params.id)));
  app.post('/api/shares/:id/checkin', h((req) => service.checkin(req.user, req.params.id)));

  // orders, vendor, admin
  app.get('/api/orders/:id', h((req) => service.getOrder(req.user, req.params.id)));
  app.post('/api/orders/:id/handover', h((req) => service.handover(req.user, req.params.id, req.body ?? {})));
  app.get('/api/vendor/dashboard', h((req) => service.vendorDashboard(req.user)));
  app.get('/api/admin/communities/:id', h((req) => service.adminCommunity(req.user, req.params.id)));
  app.post('/api/admin/nudge', h((req) => service.nudge(req.user, req.body ?? {})));

  app.use((req, res, next) => next(new DomainError('NOT_FOUND', `No route ${req.method} ${req.path}`, 404)));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err instanceof DomainError) return res.status(err.status).json({ error: { code: err.code, message: err.message } });
    if (err?.type === 'entity.parse.failed') return res.status(400).json({ error: { code: 'BAD_JSON', message: 'The request body is not valid JSON.' } });
    logger.error?.(`[api] ${req.method} ${req.path} → ${err?.stack ?? err}`);
    res.status(500).json({ error: { code: 'INTERNAL', message: 'Something went wrong on our side.' } });
  });
  return app;
}

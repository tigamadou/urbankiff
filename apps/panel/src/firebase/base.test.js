describe('base.js sans configuration', () => {
  it("s'importe sans erreur et désactive Firebase", () => {
    Object.keys(process.env)
      .filter((cle) => cle.startsWith('REACT_APP_FIREBASE_'))
      .forEach((cle) => delete process.env[cle])
    jest.isolateModules(() => {
      const base = require('./base')
      expect(base.firebaseActif).toBe(false)
      expect(base.db).toBeNull()
      expect(base.auth).toBeNull()
      expect(base.menusRef).toBeNull()
    })
  })
})

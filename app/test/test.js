const chai = require('chai');
const chaiHttp = require('chai-http');
const { expect } = chai;

chai.use(chaiHttp);

const app = require('../index'); // Ensure this correctly points to your Express app

describe('Express App Tests', () => {
    it('should return "Hello, CI/CD!" on GET /', (done) => {
        chai.request(app)
            .get('https://3000-tejasdurge5-dbbackupand-si4pedmpfzm.ws-us118.gitpod.io/')
            .end((err, res) => {
                expect(res).to.have.status(200);
                expect(res.text).to.equal('Hello, CI/CD!');
                done();
            });
    });
});

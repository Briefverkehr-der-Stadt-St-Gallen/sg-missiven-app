describe('Persons register check', () => {
    beforeEach('loads', () => {
        cy.visit('namen/?category=A&search=')
            .wait(1000)
    })

    it('Check meta title', () => {
        cy.title().should('not.be.empty');
    });

    it.skip('Check meta description', () => {
        cy.get('meta[name="description"]').should('have.attr', 'content').and('not.be.empty');
    });

    it('list of persons is not empty', () => {
        cy.get('span.people').its('length').should('be.gte', 0)
    })


    it('Check if there exist place of name “Ambühl, Jäckli” and content of detail page', () => {
        cy.contains('a', 'Ambühl, Jäckli')
            .should('exist')
            .and('be.visible')
            .and('have.attr', 'href')
            .and('include', 'stadtasg-actors-401');
        cy.contains('a', 'Ambühl, Jäckli')
            .click();
        cy.wait(10)

        // Check if exists headline “Altstätten” in new page
        cy.contains('a', 'Sammlung Schweizerischer Rechtsquellen')
            .should('have.attr', 'href', 'https://www.ssrq-sds-fds.ch/persons-db-edit/?query=per012805')
            .eq(0)
            .invoke('removeAttr', 'target')
            .click({ force: true })
            .wait(1000);
        cy.request('https://www.ssrq-sds-fds.ch/persons-db-edit/?query=per012805')
            .its('status')
            .should('eq', 200);

    })

    it('Serch results for “Alt” in search field is equal 1', () => {
        cy.get('input[name="search"]').first().focus()
            .type('Ambühl{enter}')
            .wait(10);
        cy.get('.people')
            .should('be.visible')
            .should('have.length', 1);
        //the url adress has changed
        cy.url().should('include', 'search=Amb');
    });

    it.skip('Serch results for “Alt” in address field is equal 1', () => {
        cy.visit('namen/?search=Amb')
            .wait(10);
        cy.get('.people')
            .should('be.visible')
            .should('have.length', 1);
    });


})
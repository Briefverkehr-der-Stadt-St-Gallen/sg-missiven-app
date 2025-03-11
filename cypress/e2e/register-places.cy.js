describe('Places register check', () => {
  beforeEach('loads', () => {
    cy.visit('orte/?category=A&search=')
      .wait(1000)
  })

  it('Check meta title', () => {
    cy.title().should('not.be.empty');
  });

  it.skip('Check meta description', () => {
    cy.get('meta[name="description"]').should('have.attr', 'content').and('not.be.empty');
  });

  it('list of places is not empty', () => {
    cy.get('span.place').its('length').should('be.gte', 0)
  })


  it('Check if there exist place of name “Altstätten” and content of detail page', () => {
    cy.contains('a', 'Altstätten')
      .should('exist')
      .and('be.visible')
      .and('have.attr', 'href')
      .and('include', 'stadtasg-places-11');
    cy.contains('a', 'Altstätten')
      .click();
    cy.wait(10)

    // Check if exists headline “Altstätten” in new page
    cy.contains('h1', 'Altstätten').should('be.visible')
      .should('have.id', 'locations')
      .find('pb-geolocation[latitude="47.37766"][longitude="9.54746"][label="Altstätten"]')
  })

  it('Serch results for “Alt” in search field is equal 2', () => {
    cy.get('input[name="search"]').first().focus()
      .type('Alt{enter}')
      .wait(10);
    cy.get('.place')
      .should('be.visible')
      .should('have.length', 2);
      //the url adress has changed
    cy.url().should('include', 'search=Alt');
  });

  it.skip('Serch results for “Alt” in address field is equal 2', () => {
    cy.visit('orte/?search=Alt')
    .wait(1000);
    cy.get('.place')
      .should('be.visible')
      .should('have.length', 2);
  });


})
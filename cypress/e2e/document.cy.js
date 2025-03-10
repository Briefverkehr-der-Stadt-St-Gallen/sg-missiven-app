describe('Single document check', () => {
  beforeEach('loads', () => {
    cy.visit('data/stasg_missiv_00006.xml?mode=off&view=single&odd=rqzh')
  });

  it('Check meta title', () => {
    cy.title().should('not.be.empty');
  });

  it.skip('Check meta description', () => {
    cy.get('meta[name="description"]').should('have.attr', 'content').and('not.be.empty');
  });

  it('Document title is in the header', () => {
    cy.contains('h1', 'Ulrich Zeph an Bürgermeister und Rat zu St. Gallen').should('be.visible')
  });

  it('organisation of name Bürgermeister und Rat zu St. Gallen (1426–) is in register', () => {
    cy.get('ul.persons')
      .contains('a', 'Bürgermeister und Rat zu St. Gallen')
      .should('exist')
      .should('have.length', 1)
      .and('have.attr', 'href', '../namen/Bürgermeister und Rat zu St. Gallen?key=stadtasg-actors-148')
      .click()
    cy.wait(10)
    cy.contains('h1', 'Name: Bürgermeister und Rat zu St. Gallen').should('be.visible')
      .should('have.id', 'locations');
  })

  it('Organisation of name Bürgermeister und Rat zu St. Gallen is mentioned in the text', () => {
    cy.get('pb-popover[data-ref="stadtasg-actors-148"]')
      .find('span[slot="alternate"]')
      .should('exist')
      .should('contain', 'Organisation: ')
      .should('contain', 'Bürgermeister und Rat zu St. Gallen')
  })

  it.only('Organisation of name Bürgermeister und Rat zu St. Gallen description opens register page', () => {
    cy.get('pb-popover[data-ref="stadtasg-actors-148"]')
      .find('span[slot="default"]')
      .eq(0)
      .trigger('mouseover') // Symuluje najechanie kursorem
      .should('have.css', 'cursor', 'pointer')

      .click()
    cy.wait(10)


    // Check if exists headline “Name: Bürgermeister und Rat zu St. Gallen”  in new page
    cy.contains('h1', 'Name: Bürgermeister und Rat zu St. Gallen').should('be.visible')
      .should('have.id', 'locations');
  })

  it('Organisation of name Bürgermeister und Rat zu St. Gallen link opens register page', () => {
    cy.get('pb-popover[data-ref="stadtasg-actors-148"]')
      .find('a[href="../namen/Bürgermeister und Rat zu St. Gallen?key=stadtasg-actors-148"]')
      .eq(0)
      .invoke('removeAttr', 'target')
      .click({ force: true })
    cy.wait(10)


    // Check if exists headline “Name: Bürgermeister und Rat zu St. Gallen”  in new page
    cy.contains('h1', 'Name: Bürgermeister und Rat zu St. Gallen').should('be.visible')
      .should('have.id', 'locations');
  })

})